// Storage: private bucket `media`, write prefixes, read rules per path family.
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  anon,
  closeDb,
  createGroup,
  createMedia,
  createUsers,
  rpc,
  sql,
  TINY_JPEG,
  upload,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, stranger: TestUser;
let g: TestGroup;

const canSign = async (u: TestUser, path: string) =>
  (await u.client.storage.from('media').createSignedUrl(path, 60)).error === null;
const tryUpload = async (u: TestUser, path: string, contentType = 'image/jpeg') =>
  (await u.client.storage.from('media').upload(path, TINY_JPEG, { contentType })).error;

beforeAll(async () => {
  [a, b, stranger] = await createUsers(3, 'Sto');
  g = await createGroup(a, [b]);
});

afterAll(closeDb);

describe('bucket', () => {
  it('is private and restricted to media types', async () => {
    const [bucket] = await sql(`select public, allowed_mime_types from storage.buckets where id = 'media'`);
    expect(bucket.public).toBe(false);
    expect(bucket.allowed_mime_types).toContain('image/jpeg');
    expect(await tryUpload(a, `u/${a.id}/${randomUUID()}/x.txt`, 'text/plain')).not.toBeNull();
    const pub = anon.storage.from('media').getPublicUrl(`u/${a.id}/x.jpg`).data.publicUrl;
    const res = await fetch(pub);
    expect(res.ok).toBe(false);
  });
});

describe('writes', () => {
  it('only under u/<self>/ and avatars/<self>/, insert-only', async () => {
    const own = `u/${a.id}/${randomUUID()}/original.jpg`;
    expect(await tryUpload(a, own)).toBeNull();
    expect(await tryUpload(a, `avatars/${a.id}/${randomUUID()}.jpg`)).toBeNull();
    expect(await tryUpload(a, `u/${b.id}/${randomUUID()}/x.jpg`)).not.toBeNull();
    expect(await tryUpload(a, `avatars/${b.id}/x.jpg`)).not.toBeNull();
    expect(await tryUpload(a, `g/${g.id}/collages/x.jpg`)).not.toBeNull();
    expect(await tryUpload(a, `other/${a.id}/x.jpg`)).not.toBeNull();
    // no overwrite of an existing object (no UPDATE policy)
    const up = await a.client.storage.from('media').upload(own, TINY_JPEG, { contentType: 'image/jpeg', upsert: true });
    expect(up.error).not.toBeNull();
    // anon cannot write
    const an = await anon.storage.from('media').upload(`u/${a.id}/${randomUUID()}/y.jpg`, TINY_JPEG, { contentType: 'image/jpeg' });
    expect(an.error).not.toBeNull();
  });

  it('users can delete their own avatars only; media files are deleted by the worker', async () => {
    const av = `avatars/${a.id}/${randomUUID()}.jpg`;
    await upload(a, av);
    await b.client.storage.from('media').remove([av]);
    expect(await sql(`select 1 from storage.objects where name = $1`, [av])).toHaveLength(1);
    await a.client.storage.from('media').remove([av]);
    expect(await sql(`select 1 from storage.objects where name = $1`, [av])).toEqual([]);
    const m = await createMedia(a);
    await a.client.storage.from('media').remove([m.originalPath]);
    expect(await sql(`select 1 from storage.objects where name = $1`, [m.originalPath])).toHaveLength(1);
  });
});

describe('reads', () => {
  it('media folder: owner always; members of a group where it is posted', async () => {
    const m = await createMedia(a, { dual: true });
    expect(await canSign(a, m.originalPath)).toBe(true);
    expect(await canSign(b, m.originalPath)).toBe(false); // not posted yet
    await rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g.id] });
    expect(await canSign(b, m.originalPath)).toBe(true);
    expect(await canSign(b, m.frontPath!)).toBe(true);
    expect(await canSign(stranger, m.originalPath)).toBe(false);
    // renditions written by the worker in the same folder follow the same rule
    const r = `u/${a.id}/${m.id}/r/widget.jpg`;
    await admin.storage.from('media').upload(r, TINY_JPEG, { contentType: 'image/jpeg' });
    expect(await canSign(b, r)).toBe(true);
    expect(await canSign(stranger, r)).toBe(false);
  });

  it('chat voice messages and covers: readable where the referencing row is', async () => {
    const voice = `u/${b.id}/voice/${randomUUID()}.m4a`;
    await upload(b, voice, 'audio/mp4');
    expect(await canSign(a, voice)).toBe(false);
    await rpc(b.client, 'send_message', { p_group_id: g.id, p_kind: 'voice', p_voice_path: voice, p_voice_duration_ms: 500 });
    expect(await canSign(a, voice)).toBe(true);
    expect(await canSign(stranger, voice)).toBe(false);

    const cover = `u/${a.id}/covers/${randomUUID()}.jpg`;
    await upload(a, cover);
    expect(await canSign(b, cover)).toBe(false);
    await rpc(a.client, 'update_group', { p_group_id: g.id, p_cover_path: cover });
    expect(await canSign(b, cover)).toBe(true);
    expect(await canSign(stranger, cover)).toBe(false);
  });

  it('avatars: self and people sharing a group', async () => {
    const av = `avatars/${b.id}/${randomUUID()}.jpg`;
    await upload(b, av);
    expect(await canSign(b, av)).toBe(true);
    expect(await canSign(a, av)).toBe(true);
    expect(await canSign(stranger, av)).toBe(false);
  });

  it('g/<group>/: members only', async () => {
    const p = `g/${g.id}/collages/${randomUUID()}/v1.jpg`;
    await admin.storage.from('media').upload(p, TINY_JPEG, { contentType: 'image/jpeg' });
    expect(await canSign(a, p)).toBe(true);
    expect(await canSign(b, p)).toBe(true);
    expect(await canSign(stranger, p)).toBe(false);
    const { data } = await b.client.storage.from('media').list(`g/${g.id}/collages`);
    expect((data ?? []).length).toBeGreaterThan(0);
    const { data: none } = await stranger.client.storage.from('media').list(`g/${g.id}/collages`);
    expect(none ?? []).toEqual([]);
  });

  it('a removed member loses access', async () => {
    const [c] = await createUsers(1, 'Rm');
    const inv = await rpc(a.client, 'create_invite', { p_group_id: g.id });
    await rpc(c.client, 'join_group', { p_token: inv.token });
    const m = await createMedia(a);
    await rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g.id] });
    expect(await canSign(c, m.originalPath)).toBe(true);
    await rpc(a.client, 'remove_member', { p_group_id: g.id, p_user_id: c.id });
    expect(await canSign(c, m.originalPath)).toBe(false);
  });
});
