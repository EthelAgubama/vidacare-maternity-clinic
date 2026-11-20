// VidaCare: clinician access to midwife-department records, only through an open referral.
// Routes (HTTP API, Cognito JWT checked by API Gateway before this code runs):
//   GET  /referrals            open referrals waiting for a clinician
//   GET  /referrals/{id}       summary of that client's record (and logs the access)
//   POST /referrals/{id}/seen  clinician marks it seen: access ends
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, QueryCommand, ScanCommand, UpdateCommand, PutCommand } from '@aws-sdk/lib-dynamodb';

const T = {
  ref: process.env.REFERRAL_TABLE, pat: process.env.PATIENT_TABLE, anc: process.env.ANC_TABLE, pn: process.env.PN_TABLE, cw: process.env.CW_TABLE,
  rx: process.env.RX_TABLE, labreq: process.env.LABREQ_TABLE, labres: process.env.LABRES_TABLE,
};
const DEPT_TABLE = { antenatal: 'anc', postnatal: 'pn', 'child-welfare': 'cw' };
const DEPT_LABEL = { antenatal: 'Antenatal', postnatal: 'Postnatal', 'child-welfare': 'Child welfare' };
export const deps = { db: DynamoDBDocumentClient.from(new DynamoDBClient({}), { marshallOptions: { removeUndefinedValues: true } }), now: () => new Date() };

const resp = (code, body) => ({ statusCode: code, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
const groupsOf = claims => String(claims['cognito:groups'] || '').replace(/[\[\]"]/g, '').split(/[\s,]+/).filter(Boolean);
const num = v => (v === undefined || v === null || v === '') ? null : Number(v);
const dstr = s => s ? String(s).slice(0, 10) : '';
const kg = g => g === null || isNaN(g) ? '' : (g / 1000) + ' kg';
const expired = r => r.expires_at && new Date(r.expires_at) < deps.now();
const isOpen = r => r.status === 'open' && !expired(r);

async function queryAll(table, pid) {
  let items = [], key;
  do { const r = await deps.db.send(new QueryCommand({ TableName: table, KeyConditionExpression: 'patient_id = :p', ExpressionAttributeValues: { ':p': pid }, ExclusiveStartKey: key })); items = items.concat(r.Items || []); key = r.LastEvaluatedKey; } while (key);
  return items;
}
async function scanFor(table, pid) {
  let items = [], key;
  do { const r = await deps.db.send(new ScanCommand({ TableName: table, FilterExpression: 'patient_id = :p', ExpressionAttributeValues: { ':p': pid }, ExclusiveStartKey: key })); items = items.concat(r.Items || []); key = r.LastEvaluatedKey; } while (key);
  return items;
}
async function log(ref, claims, action) {
  const at = deps.now().toISOString();
  await deps.db.send(new PutCommand({ TableName: T.ref, Item: { referral_id: `log#${at}#${Math.random().toString(36).slice(2, 8)}`, record_type: 'access-log', for_referral: ref.referral_id, patient_id: ref.patient_id, patient_name: ref.patient_name, from_dept: ref.from_dept, action, by: claims.name || claims['cognito:username'], by_username: claims['cognito:username'], at } }));
}

// ---- department summaries: what the clinician is shown, nothing more ----
async function deptSummary(ref) {
  const table = T[DEPT_TABLE[ref.from_dept]]; if (!table) return { facts: [], visits: [] };
  const recs = await queryAll(table, ref.patient_id), by = t => recs.filter(r => r.record_type === t);
  const facts = [], visits = [];
  if (ref.from_dept === 'antenatal') {
    const pg = recs.find(r => r.record_id === ref.source_record_id) || by('pregnancy').sort((a, b) => String(b.booked_date).localeCompare(String(a.booked_date)))[0];
    if (pg) {
      facts.push(['Pregnancy', [pg.reg_no ? 'ANC ' + pg.reg_no : '', pg.edd ? 'EDD ' + pg.edd : '', 'G' + (pg.gravida ?? '?') + ' P' + (pg.para ?? '?'), pg.blood_group ? 'Blood group ' + pg.blood_group : ''].filter(Boolean).join(' · ')]);
      if (pg.risk_hx) facts.push(['Risk history', String(pg.risk_hx).split('|').join(', ')]);
    }
    by('anc-visit').filter(v => !pg || v.preg_id === pg.record_id).sort((a, b) => String(b.visit_date).localeCompare(String(a.visit_date))).slice(0, 5).forEach(v => {
      const l = [];
      if (v.bp_sys) l.push(`BP ${v.bp_sys}/${v.bp_dia}`); if (v.weight) l.push(`weight ${v.weight} kg`); if (v.fundal) l.push(`fundal height ${v.fundal} cm`); if (v.fhr) l.push(`fetal heart ${v.fhr}`);
      if (v.hb) l.push(`Hb ${v.hb}`); if (v.urine_protein && v.urine_protein !== 'Not done') l.push(`urine protein ${v.urine_protein}`); if (v.oedema && v.oedema !== 'None') l.push(`oedema ${v.oedema}`); if (v.malaria && v.malaria !== 'Not done') l.push(`malaria ${v.malaria}`);
      if (v.danger) l.push('DANGER SIGNS: ' + String(v.danger).split('|').join(', '));
      visits.push({ date: v.visit_date, by: v.entered_by, text: l.join(' · ') || 'Visit recorded' });
    });
  } else if (ref.from_dept === 'postnatal') {
    const ep = recs.find(r => r.record_id === ref.source_record_id) || by('postnatal')[0];
    if (ep) facts.push(['Postnatal', [ep.pn_no ? 'PNC ' + ep.pn_no : '', ep.birth_at ? 'delivered ' + dstr(ep.birth_at) : ''].filter(Boolean).join(' · ')]);
    by('postnatal-visit').filter(v => !ep || v.pn_id === ep.record_id).sort((a, b) => String(b.visit_at).localeCompare(String(a.visit_at))).slice(0, 5).forEach(v => {
      const l = [];
      if (v.m_sys) l.push(`BP ${v.m_sys}/${v.m_dia}`); if (v.m_pulse) l.push(`pulse ${v.m_pulse}`); if (v.m_temp) l.push(`temp ${v.m_temp}`); if (v.uterus) l.push(`womb ${v.uterus}`); if (v.lochia_amount) l.push(`lochia ${v.lochia_amount}`); if (v.incision) l.push(`wound ${v.incision}`); if (v.hb) l.push(`Hb ${v.hb}`);
      if (v.danger) l.push('DANGER SIGNS: ' + String(v.danger).split('|').join(', ')); if (v.alerts) l.push('Flagged: ' + v.alerts);
      visits.push({ date: dstr(v.visit_at), by: v.entered_by, text: l.join(' · ') || 'Visit recorded' });
    });
  } else if (ref.from_dept === 'child-welfare') {
    const ep = recs.find(r => r.record_id === ref.source_record_id) || by('child-welfare')[0];
    if (ep) facts.push(['Child welfare', [ep.cw_no ? 'CWC ' + ep.cw_no : '', ep.birth_weight ? 'birth weight ' + kg(num(ep.birth_weight)) : '', ep.premature === 'Yes' ? 'born before 37 weeks' : ''].filter(Boolean).join(' · ')]);
    by('child-welfare-visit').filter(v => !ep || v.cw_id === ep.record_id).sort((a, b) => String(b.visit_at).localeCompare(String(a.visit_at))).slice(0, 5).forEach(v => {
      const l = [];
      if (v.weight) l.push(`weight ${kg(num(v.weight))}`); if (v.length) l.push(`length ${v.length} cm`); if (v.muac) l.push(`MUAC ${v.muac} cm`); if (v.zone) l.push(String(v.zone).split(' (')[0]); if (v.temp) l.push(`temp ${v.temp}`);
      if (v.illness) l.push('illness: ' + String(v.illness).split('|').join(', ')); if (v.danger) l.push('DANGER SIGNS: ' + String(v.danger).split('|').join(', ')); if (v.alerts) l.push('Flagged: ' + v.alerts);
      visits.push({ date: dstr(v.visit_at), by: v.entered_by, text: l.join(' · ') || 'Visit recorded' });
    });
  }
  return { facts, visits };
}
async function medicines(pid) {
  return (await scanFor(T.rx, pid)).sort((a, b) => String(b.prescribed_at).localeCompare(String(a.prescribed_at))).slice(0, 8).map(r => {
    let items = []; try { items = JSON.parse(r.items_json || '[]'); } catch (e) { /* ignore */ }
    return { date: dstr(r.prescribed_at), by: r.prescribed_by, status: r.status, items: items.map(i => [i.n, i.d, i.r, i.f, i.i].filter(Boolean).join(' ')) };
  });
}
async function results(pid) {
  const reqs = (await scanFor(T.labreq, pid)).filter(r => r.status === 'released').sort((a, b) => String(b.released_at).localeCompare(String(a.released_at))).slice(0, 8), out = [];
  for (const r of reqs) {
    const x = (await deps.db.send(new GetCommand({ TableName: T.labres, Key: { patient_id: pid, record_id: r.request_id } }))).Item || {};
    out.push({ date: dstr(r.released_at), test: r.test, flag: r.result_flag || x.flag || '', result: x.result_text || [x.result_value, x.unit].filter(Boolean).join(' ') || '' });
  }
  return out;
}

export const handler = async event => {
  try {
    const claims = (event.requestContext && event.requestContext.authorizer && event.requestContext.authorizer.jwt && event.requestContext.authorizer.jwt.claims) || {};
    if (!groupsOf(claims).includes('clinicians')) return resp(403, { error: 'Only clinicians can use referral access.' });
    const route = event.routeKey, id = event.pathParameters && event.pathParameters.id;
    if (route === 'GET /referrals') {
      let items = [], key;
      do { const r = await deps.db.send(new ScanCommand({ TableName: T.ref, FilterExpression: 'begins_with(referral_id, :r) AND #s = :o', ExpressionAttributeNames: { '#s': 'status' }, ExpressionAttributeValues: { ':r': 'ref#', ':o': 'open' }, ExclusiveStartKey: key })); items = items.concat(r.Items || []); key = r.LastEvaluatedKey; } while (key);
      return resp(200, { referrals: items.filter(isOpen).sort((a, b) => (a.urgency === 'Urgent' ? 0 : 1) - (b.urgency === 'Urgent' ? 0 : 1) || String(a.created_at).localeCompare(String(b.created_at))).map(r => ({ referral_id: r.referral_id, patient_id: r.patient_id, patient_name: r.patient_name, client_id: r.client_id, from_dept: r.from_dept, from_label: DEPT_LABEL[r.from_dept] || r.from_dept, reason: r.reason, urgency: r.urgency, created_at: r.created_at, created_by: r.created_by, expires_at: r.expires_at })) });
    }
    if (!id || !String(id).startsWith('ref#')) return resp(404, { error: 'Not found.' });
    const ref = (await deps.db.send(new GetCommand({ TableName: T.ref, Key: { referral_id: id } }))).Item;
    if (!ref || ref.record_type === 'access-log') return resp(404, { error: 'This referral was not found.' });
    if (!isOpen(ref)) return resp(403, { error: ref.status === 'seen' ? 'This referral has been marked as seen, so access has ended.' : 'This referral has expired, so access has ended. Ask the midwife to refer again if you still need the record.' });
    if (route === 'GET /referrals/{id}') {
      const [dept, rx, labs, pat] = await Promise.all([deptSummary(ref), medicines(ref.patient_id), results(ref.patient_id), deps.db.send(new GetCommand({ TableName: T.pat, Key: { patient_id: ref.patient_id, record_type: 'profile' } }))]);
      await log(ref, claims, 'viewed summary');
      const p = pat.Item || {};
      return resp(200, { referral: { referral_id: ref.referral_id, from_label: DEPT_LABEL[ref.from_dept], reason: ref.reason, urgency: ref.urgency, created_by: ref.created_by, created_at: ref.created_at, expires_at: ref.expires_at },
        client: { patient_id: ref.patient_id, name: ref.patient_name, client_id: ref.client_id, sex: p.sex, date_of_birth: p.date_of_birth, allergies: p.allergies }, facts: dept.facts, visits: dept.visits, medicines: await Promise.resolve(rx), results: labs });
    }
    if (route === 'POST /referrals/{id}/seen') {
      const at = deps.now().toISOString();
      await deps.db.send(new UpdateCommand({ TableName: T.ref, Key: { referral_id: id }, UpdateExpression: 'SET #s = :s, seen_at = :t, seen_by = :b, seen_by_username = :u', ConditionExpression: '#s = :o', ExpressionAttributeNames: { '#s': 'status' }, ExpressionAttributeValues: { ':s': 'seen', ':o': 'open', ':t': at, ':b': claims.name || claims['cognito:username'], ':u': claims['cognito:username'] } }));
      await log(ref, claims, 'marked seen, access ended');
      return resp(200, { ok: true });
    }
    return resp(404, { error: 'Not found.' });
  } catch (e) {
    console.error(e);
    return resp(500, { error: 'Something went wrong. Please try again.' });
  }
};
