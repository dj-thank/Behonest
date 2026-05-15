import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

admin.initializeApp();

const db = admin.firestore();
const region = 'asia-northeast1';
const defaultCaptureWindowMinutes = 15;
const jstOffsetMs = 9 * 60 * 60 * 1000;

type TripData = {
  name?: string;
  ownerId?: string;
  inviteCode?: string;
  memberIds?: string[];
  active?: boolean;
  startDate?: Timestamp;
  endDate?: Timestamp;
  timezone?: string;
  dailyMomentCount?: number;
  captureWindowMinutes?: number;
};

type MemberToken = {
  uid: string;
  token: string;
  tokenPath: string;
  soundKey: string;
};

const soundMap: Record<string, {
  androidChannelId: string;
  androidSound: string;
  iosSound: string;
}> = {
  honest_ping: {
    androidChannelId: 'be_honest_honest_ping_v2',
    androidSound: 'honest_ping',
    iosSound: 'honest_ping.caf',
  },
  travel_bell: {
    androidChannelId: 'be_honest_travel_bell_v2',
    androidSound: 'travel_bell',
    iosSound: 'travel_bell.caf',
  },
  camera_pop: {
    androidChannelId: 'be_honest_camera_pop_v2',
    androidSound: 'camera_pop',
    iosSound: 'camera_pop.caf',
  },
};

export const joinTrip = onCall({ region }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');

  const inviteCode = String(request.data?.inviteCode ?? '').trim().toUpperCase();
  if (!inviteCode) {
    throw new HttpsError('invalid-argument', 'inviteCode is required.');
  }

  const result = await db
    .collection('trips')
    .where('inviteCode', '==', inviteCode)
    .limit(1)
    .get();

  if (result.empty) {
    throw new HttpsError('not-found', '招待コードが見つかりません。');
  }

  const tripRef = result.docs[0].ref;
  const trip = result.docs[0].data() as TripData;
  if (trip.active === false) {
    throw new HttpsError('failed-precondition', 'この旅行は終了しています。');
  }

  await tripRef.update({
    memberIds: FieldValue.arrayUnion(uid),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, tripId: tripRef.id };
});

export const startMoment = onCall({ region }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');

  const tripId = String(request.data?.tripId ?? '');
  if (!tripId) throw new HttpsError('invalid-argument', 'tripId is required.');

  const tripRef = db.collection('trips').doc(tripId);
  const tripSnap = await tripRef.get();
  if (!tripSnap.exists) throw new HttpsError('not-found', '旅行が見つかりません。');

  const trip = tripSnap.data() as TripData;
  const memberIds = trip.memberIds ?? [];
  if (!memberIds.includes(uid)) {
    throw new HttpsError('permission-denied', 'この旅行のメンバーではありません。');
  }
  if (trip.ownerId !== uid) {
    throw new HttpsError('permission-denied', '通知開始は旅行の作成者だけができます。');
  }

  const existing = await findOpenMoment(tripId);
  if (existing) {
    return { ok: true, momentId: existing.id, reused: true };
  }

  const momentRef = await createMoment(tripId, trip, uid, 'active');
  await sendMomentNotification({ tripId, momentId: momentRef.id, trip });

  return { ok: true, momentId: momentRef.id, reused: false };
});

export const planDailyMoments = onSchedule(
  {
    region,
    schedule: '5 0 * * *',
    timeZone: 'Asia/Tokyo',
  },
  async () => {
    const now = new Date();
    const trips = await db.collection('trips').where('active', '==', true).get();

    for (const tripSnap of trips.docs) {
      const trip = tripSnap.data() as TripData;
      if (!isTripInDateWindow(trip, now)) continue;

      const plannedKey = dateKeyJst(now);
      const alreadyPlanned = await tripSnap.ref
        .collection('moments')
        .where('plannedDateKey', '==', plannedKey)
        .limit(1)
        .get();
      if (!alreadyPlanned.empty) continue;

      const count = clampNumber(trip.dailyMomentCount ?? 1, 1, 3);
      const times = randomMomentTimesJst(now, count);

      for (const startsAt of times) {
        await createMoment(tripSnap.id, trip, 'cloud', 'scheduled', startsAt, plannedKey);
      }
    }
  },
);

export const dispatchDueMoments = onSchedule(
  {
    region,
    schedule: 'every 5 minutes',
    timeZone: 'Asia/Tokyo',
  },
  async () => {
    const now = Timestamp.now();
    const due = await db
      .collectionGroup('moments')
      .where('status', '==', 'scheduled')
      .where('startsAt', '<=', now)
      .limit(50)
      .get();

    for (const momentSnap of due.docs) {
      const tripRef = momentSnap.ref.parent.parent;
      if (!tripRef) continue;

      const tripSnap = await tripRef.get();
      if (!tripSnap.exists) continue;

      const trip = tripSnap.data() as TripData;
      await momentSnap.ref.update({
        status: 'active',
        dispatchedAt: FieldValue.serverTimestamp(),
      });
      await sendMomentNotification({
        tripId: tripRef.id,
        momentId: momentSnap.id,
        trip,
      });
    }
  },
);

export const expireOldMoments = onSchedule(
  {
    region,
    schedule: 'every 15 minutes',
    timeZone: 'Asia/Tokyo',
  },
  async () => {
    const now = Timestamp.now();
    const expired = await db
      .collectionGroup('moments')
      .where('status', '==', 'active')
      .where('expiresAt', '<=', now)
      .limit(100)
      .get();

    const batch = db.batch();
    for (const doc of expired.docs) {
      batch.update(doc.ref, {
        status: 'expired',
        expiredAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  },
);

async function findOpenMoment(tripId: string) {
  const now = Timestamp.now();
  const existing = await db
    .collection('trips')
    .doc(tripId)
    .collection('moments')
    .where('status', '==', 'active')
    .where('expiresAt', '>', now)
    .orderBy('expiresAt', 'desc')
    .limit(1)
    .get();
  return existing.empty ? null : existing.docs[0].ref;
}

async function createMoment(
  tripId: string,
  trip: TripData,
  createdBy: string,
  status: 'scheduled' | 'active',
  startsAtDate = new Date(),
  plannedDateKey?: string,
) {
  const windowMinutes = clampNumber(
    trip.captureWindowMinutes ?? defaultCaptureWindowMinutes,
    2,
    60,
  );
  const startsAt = Timestamp.fromDate(startsAtDate);
  const expiresAt = Timestamp.fromMillis(startsAtDate.getTime() + windowMinutes * 60 * 1000);
  return db.collection('trips').doc(tripId).collection('moments').add({
    tripId,
    status,
    startsAt,
    expiresAt,
    createdBy,
    plannedDateKey: plannedDateKey ?? dateKeyJst(startsAtDate),
    captureWindowMinutes: windowMinutes,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function sendMomentNotification(params: {
  tripId: string;
  momentId: string;
  trip: TripData;
}) {
  const { tripId, momentId, trip } = params;
  const memberIds = trip.memberIds ?? [];
  const tokens = await tokensForMembers(memberIds);
  if (tokens.length === 0) return;

  const title = 'Be Honest time 📸';
  const body = `${trip.name ?? '旅行'}の今を撮ろう`;
  const grouped = groupBySound(tokens);

  for (const [soundKey, group] of grouped.entries()) {
    const sound = soundMap[soundKey] ?? soundMap.honest_ping;
    for (const chunk of chunkArray(group, 500)) {
      const result = await admin.messaging().sendEachForMulticast({
        tokens: chunk.map((item) => item.token),
        notification: { title, body },
        data: {
          type: 'moment',
          tripId,
          momentId,
          soundKey,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          notification: {
            channelId: sound.androidChannelId,
            sound: sound.androidSound,
            priority: 'high',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: sound.iosSound,
            },
          },
        },
      });

      await cleanupInvalidTokens(chunk, result.responses);
    }
  }
}

async function tokensForMembers(memberIds: string[]) {
  const output: MemberToken[] = [];
  const seen = new Set<string>();

  for (const uid of memberIds) {
    const userRef = db.collection('users').doc(uid);
    const [userSnap, tokenSnap] = await Promise.all([
      userRef.get(),
      userRef.collection('tokens').get(),
    ]);
    const userData = (userSnap.data() ?? {}) as { selectedSoundKey?: unknown };
    const selectedSoundKey = sanitizeSoundKey(userData.selectedSoundKey);

    for (const doc of tokenSnap.docs) {
      const token = doc.data().token;
      if (typeof token !== 'string' || token.length === 0 || seen.has(token)) continue;
      seen.add(token);
      output.push({
        uid,
        token,
        tokenPath: doc.ref.path,
        soundKey: selectedSoundKey,
      });
    }
  }
  return output;
}

function groupBySound(tokens: MemberToken[]) {
  const groups = new Map<string, MemberToken[]>();
  for (const item of tokens) {
    const key = sanitizeSoundKey(item.soundKey);
    groups.set(key, [...(groups.get(key) ?? []), item]);
  }
  return groups;
}

async function cleanupInvalidTokens(
  chunk: MemberToken[],
  responses: admin.messaging.SendResponse[],
) {
  const deletes: Promise<unknown>[] = [];
  responses.forEach((response, index) => {
    if (response.success) return;
    const code = response.error?.code ?? '';
    if (isInvalidTokenError(code)) {
      deletes.push(db.doc(chunk[index].tokenPath).delete());
    }
  });
  await Promise.all(deletes);
}

function isInvalidTokenError(code: string) {
  return code === 'messaging/invalid-registration-token'
    || code === 'messaging/registration-token-not-registered';
}

function sanitizeSoundKey(value: unknown) {
  const key = typeof value === 'string' ? value : 'honest_ping';
  return soundMap[key] ? key : 'honest_ping';
}

function isTripInDateWindow(trip: TripData, now: Date) {
  const start = trip.startDate?.toDate();
  const end = trip.endDate?.toDate();
  if (!start || !end) return true;
  return now >= start && now <= end;
}

function randomMomentTimesJst(day: Date, count: number) {
  const parts = jstParts(day);
  const startHour = 9;
  const endHour = 22;
  const output: Date[] = [];
  for (let i = 0; i < count; i += 1) {
    const hour = startHour + Math.floor(Math.random() * (endHour - startHour));
    const minute = Math.floor(Math.random() * 60);
    output.push(jstDate(parts.year, parts.month, parts.day, hour, minute));
  }
  output.sort((a, b) => a.getTime() - b.getTime());
  return output;
}

function dateKeyJst(date: Date) {
  const parts = jstParts(date);
  const m = `${parts.month}`.padStart(2, '0');
  const d = `${parts.day}`.padStart(2, '0');
  return `${parts.year}-${m}-${d}`;
}

function jstParts(date: Date) {
  const shifted = new Date(date.getTime() + jstOffsetMs);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  };
}

function jstDate(year: number, month: number, day: number, hour: number, minute: number) {
  return new Date(Date.UTC(year, month - 1, day, hour - 9, minute, 0));
}

function clampNumber(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function chunkArray<T>(items: T[], size: number) {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}
