import { Link, router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Button, Card, Chip, Ring, Row, Scale, Screen, T } from '@/components/ui';
import { C, R, S } from '@/constants/theme';
import { NOISE_WORDS, QUICK_FOODS, REFILL_AT, SYMPTOMS } from '@/lib/catalog';
import { clockLabel, countdown, dayKey, greeting, lastDays, longDate, timeLabel, weekdayShort } from '@/lib/date';
import { cancelWaitOver, scheduleWaitOver } from '@/lib/notifications';
import { emptyDay, newId, proteinOf, useStore } from '@/lib/store';
import { SymptomId } from '@/lib/types';
import { useNow } from '@/hooks/use-now';

// Event-time stamp for handlers; kept outside the component so render stays pure.
const timestamp = () => Date.now();

export default function Today() {
  const { data, setAside, update, updateDay } = useStore();
  const s = data.settings;
  const key = dayKey();
  const day = data.days[key] ?? emptyDay();
  const waitMs = s.waitMinutes * 60_000;
  const now = useNow(day.takenAt !== null ? day.takenAt + waitMs : null);
  const remaining = day.takenAt !== null ? day.takenAt + waitMs - now : 0;
  const stillWaiting = day.takenAt !== null && remaining > 0;
  const protein = proteinOf(day);

  const streak = (() => {
    let n = 0;
    const days = lastDays(365).reverse();
    for (const [i, d] of days.entries()) {
      const log = data.days[dayKey(d)];
      if (log?.takenAt) n++;
      else if (i === 0) continue; // today not taken yet doesn't break it
      else break;
    }
    return n;
  })();

  const countTablets = (delta: number) =>
    update((d) =>
      d.settings.tabletsLeft === null
        ? d
        : { ...d, settings: { ...d.settings, tabletsLeft: Math.max(0, d.settings.tabletsLeft + delta) } },
    );

  const takeTablet = () => {
    const at = timestamp();
    updateDay(key, (d) => ({ ...d, takenAt: at, skipped: false }));
    countTablets(-1);
    scheduleWaitOver(at, s.waitMinutes, s.reminders.waitOver).catch(() => {});
  };
  const undoTablet = () => {
    updateDay(key, (d) => ({ ...d, takenAt: null }));
    countTablets(1);
    cancelWaitOver().catch(() => {});
  };

  const toggleSymptom = (id: SymptomId) =>
    updateDay(key, (d) => {
      const has = d.symptoms.some((x) => x.id === id);
      return {
        ...d,
        symptoms: has
          ? d.symptoms.filter((x) => x.id !== id)
          : [...d.symptoms, { id, severity: 2, triggers: [], note: '', at: Date.now() }],
      };
    });

  const dueAt = new Date(now);
  dueAt.setHours(s.doseHour, s.doseMinute, 0, 0);
  const overdue = day.takenAt === null && !day.skipped && now > dueAt.getTime() + 2 * 3600_000;

  return (
    <Screen>
      <Row style={{ justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <View style={{ gap: 4 }}>
          <T variant="label">{longDate()}</T>
          <T variant="title">{greeting()}</T>
        </View>
        <Row style={{ gap: S.sm }}>
          <View style={styles.pill}>
            <Text style={styles.pillText}>{streak}-day streak</Text>
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Medication and reminders"
            onPress={() => router.push('/medication')}
            style={styles.iconBtn}>
            <Text style={{ fontSize: 18, color: C.ink }}>⚙︎</Text>
          </Pressable>
        </Row>
      </Row>

      <WeekStrip />

      {setAside > 0 ? (
        <Pressable accessibilityRole="button" onPress={() => router.push('/data')} style={styles.refill}>
          <Text style={{ color: C.warmInk, fontSize: 14, fontWeight: '700', flex: 1 }}>
            Some saved records couldn&apos;t be read. Nothing was deleted. Tap to check.
          </Text>
          <Text style={{ color: C.warmInk, fontSize: 18 }}>›</Text>
        </Pressable>
      ) : null}

      {s.reminders.refill && s.tabletsLeft !== null && s.tabletsLeft <= REFILL_AT ? (
        <Pressable accessibilityRole="button" onPress={() => router.push('/medication')} style={styles.refill}>
          <Text style={{ color: C.warmInk, fontSize: 14, fontWeight: '700' }}>
            {s.tabletsLeft} tablets left. Time to ask for a refill.
          </Text>
          <Text style={{ color: C.warmInk, fontSize: 18 }}>›</Text>
        </Pressable>
      ) : null}

      {/* Tablet card */}
      {day.takenAt === null ? (
        <View style={[styles.hero, overdue && { backgroundColor: C.card, borderWidth: 2, borderColor: C.warm }]}>
          <Row style={{ justifyContent: 'space-between' }}>
            <Text style={[styles.heroLabel, overdue && { color: C.warmInk }]}>
              {overdue ? `Due at ${clockLabel(s.doseHour, s.doseMinute)} · not logged` : "Today's tablet"}
            </Text>
          </Row>
          <Text style={[styles.heroTitle, overdue && { color: C.ink }]}>
            {overdue ? 'Did you take your tablet this morning?' : 'Take it on an empty stomach with a small sip of water'}
          </Text>
          <Text style={[styles.heroBody, overdue && { color: C.inkSoft }]}>
            {overdue
              ? "If you missed it, follow the missed-dose instructions on your label. Don't take two to catch up."
              : `Then wait ${s.waitMinutes} min before food, drinks or other medicines, as your label says.`}
          </Text>
          <Button title={overdue ? 'Yes, I took it' : 'I took it'} kind={overdue ? 'primary' : 'light'} onPress={takeTablet} />
          {overdue ? (
            <Button
              title="I skipped today"
              kind="secondary"
              onPress={() => updateDay(key, (d) => ({ ...d, skipped: true }))}
            />
          ) : null}
        </View>
      ) : stillWaiting ? (
        <View style={styles.hero}>
          <Text style={styles.heroLabel}>Taken at {timeLabel(day.takenAt)} · empty-stomach wait</Text>
          <Row style={{ gap: S.xl }}>
            <Ring size={132} stroke={12} progress={1 - remaining / waitMs} color={C.white} track="rgba(255,255,255,0.2)">
              <Text style={styles.timer}>{countdown(remaining)}</Text>
              <Text style={styles.heroSmall}>left</Text>
            </Ring>
            <View style={{ gap: 4, flex: 1 }}>
              <Text style={styles.heroSmall}>Breakfast at</Text>
              <Text style={styles.heroTitle}>{timeLabel(day.takenAt + waitMs)}</Text>
              <Text style={styles.heroSmall}>No food, coffee or other medicines yet.</Text>
            </View>
          </Row>
          <Pressable accessibilityRole="button" onPress={undoTablet} style={{ alignSelf: 'flex-start', minHeight: 44, justifyContent: 'center' }}>
            <Text style={[styles.heroSmall, { textDecorationLine: 'underline' }]}>Logged by mistake? Undo</Text>
          </Pressable>
        </View>
      ) : (
        <View style={styles.hero}>
          <Text style={styles.heroTitle}>You&apos;re clear to eat</Text>
          <Text style={styles.heroBody}>Start with protein: about 30 g at breakfast helps protect muscle.</Text>
        </View>
      )}

      {/* Protein */}
      <Card>
        <Row style={{ gap: S.xl }}>
          <Ring size={112} stroke={12} progress={protein / s.proteinTarget} color={C.warm} track={C.lineSoft}>
            <Text style={{ fontSize: 22, fontWeight: '800', color: C.ink }}>{protein}</Text>
            <Text style={{ fontSize: 11, color: C.muted }}>of {s.proteinTarget} g</Text>
          </Ring>
          <View style={{ flex: 1, gap: 4 }}>
            <T variant="label">Protein today</T>
            <T variant="body" style={{ color: C.inkSoft }}>
              {protein >= s.proteinTarget
                ? 'Target reached. Nice work.'
                : `${s.proteinTarget - protein} g to go. Protein helps you keep muscle.`}
            </T>
          </View>
        </Row>
        <View style={styles.wrap}>
          {QUICK_FOODS.map((f) => (
            <Pressable
              key={f.name}
              accessibilityRole="button"
              accessibilityLabel={`Add ${f.short}, ${f.protein} grams protein`}
              onPress={() =>
                updateDay(key, (d) => ({
                  ...d,
                  foods: [...d.foods, { id: newId(), name: f.name, protein: f.protein, meal: 'Snack', at: Date.now() }],
                }))
              }
              style={styles.food}>
              <Text style={{ color: C.warmDark, fontWeight: '800', fontSize: 14 }}>+{f.protein} g</Text>
              <Text style={{ color: C.ink, fontWeight: '600', fontSize: 14 }}>{f.short}</Text>
            </Pressable>
          ))}
        </View>
        <Link href="/log-food" asChild>
          <Button title="Search all foods" kind="soft" />
        </Link>
      </Card>

      {/* Water / fiber / strength */}
      <View style={{ flexDirection: 'row', gap: S.md - 2 }}>
        <Mini
          label="Water"
          value={day.water}
          unit={`/${s.waterTarget}`}
          action="+ Glass"
          tint={C.accentSoft}
          ink={C.accentDark}
          onPress={() => updateDay(key, (d) => ({ ...d, water: d.water + 1 }))}
        />
        <Mini
          label="Fiber"
          value={day.fiber}
          unit={`/${s.fiberTarget} g`}
          action="+5 g"
          tint={C.sand}
          ink={C.sandInk}
          onPress={() => updateDay(key, (d) => ({ ...d, fiber: d.fiber + 5 }))}
        />
        <Mini
          label="Strength"
          value={day.strength}
          unit=" today"
          action="+ Session"
          tint={C.neutralSoft}
          ink={C.ink}
          onPress={() => updateDay(key, (d) => ({ ...d, strength: d.strength + 1 }))}
        />
      </View>

      {/* Food noise */}
      <Card>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="h2">Food noise today</T>
          <T variant="label">{day.foodNoise ? NOISE_WORDS[day.foodNoise] : 'Not logged'}</T>
        </Row>
        <Scale value={day.foodNoise} words={NOISE_WORDS} onChange={(v) => updateDay(key, (d) => ({ ...d, foodNoise: v }))} />
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="small">Quiet</T>
          <T variant="small">Constant thoughts about food</T>
        </Row>
      </Card>

      {/* Symptoms */}
      <Card>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="h2">How do you feel?</T>
          <Link href="/symptom" style={styles.link}>
            Add details
          </Link>
        </Row>
        <View style={styles.wrap}>
          {SYMPTOMS.map((sym) => (
            <Chip
              key={sym.id}
              label={sym.label}
              tone={sym.id === 'good' ? 'accent' : 'warm'}
              selected={day.symptoms.some((x) => x.id === sym.id)}
              onPress={() => toggleSymptom(sym.id)}
            />
          ))}
        </View>
      </Card>
    </Screen>
  );
}

function WeekStrip() {
  const { data } = useStore();
  const days = lastDays(7);
  return (
    <View style={{ flexDirection: 'row', gap: 6 }}>
      {days.map((d, i) => {
        const today = i === days.length - 1;
        const taken = !!data.days[dayKey(d)]?.takenAt;
        return (
          <View key={dayKey(d)} style={[styles.dayCell, today && { backgroundColor: C.ink }]}>
            <Text style={[styles.dayName, today && { color: C.white }]}>{weekdayShort(d)}</Text>
            <Text style={[styles.dayNum, today && { color: C.white }]}>{d.getDate()}</Text>
            <View
              style={{
                width: 6,
                height: 6,
                borderRadius: 3,
                backgroundColor: taken ? (today ? C.warmLight : C.accent) : today ? 'rgba(255,255,255,0.3)' : C.line,
              }}
            />
          </View>
        );
      })}
    </View>
  );
}

function Mini(props: {
  label: string;
  value: number;
  unit: string;
  action: string;
  tint: string;
  ink: string;
  onPress: () => void;
}) {
  return (
    <View style={styles.mini}>
      <T variant="label" style={{ fontSize: 12, fontWeight: '700' }}>
        {props.label}
      </T>
      <Text style={{ fontSize: 22, fontWeight: '800', color: C.ink }}>
        {props.value}
        <Text style={{ fontSize: 12, fontWeight: '600', color: C.muted }}>{props.unit}</Text>
      </Text>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${props.label}: ${props.action}`}
        onPress={props.onPress}
        style={[styles.miniBtn, { backgroundColor: props.tint }]}>
        <Text style={{ color: props.ink, fontWeight: '800', fontSize: 14 }}>{props.action}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  refill: {
    backgroundColor: C.warmSoft,
    borderRadius: R.md,
    paddingHorizontal: S.lg,
    minHeight: 52,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  pill: { backgroundColor: C.card, borderRadius: R.pill, paddingHorizontal: 12, minHeight: 36, justifyContent: 'center' },
  pillText: { fontSize: 13, fontWeight: '700', color: C.ink },
  iconBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: C.card, alignItems: 'center', justifyContent: 'center' },
  hero: { backgroundColor: C.accent, borderRadius: R.xl, padding: 22, gap: 14 },
  heroLabel: { fontSize: 13, fontWeight: '600', color: 'rgba(255,255,255,0.9)' },
  heroTitle: { fontSize: 24, fontWeight: '800', color: C.white, lineHeight: 30 },
  heroBody: { fontSize: 14, lineHeight: 21, color: 'rgba(255,255,255,0.92)' },
  heroSmall: { fontSize: 12, color: 'rgba(255,255,255,0.88)' },
  timer: { fontSize: 28, fontWeight: '800', color: C.white, fontVariant: ['tabular-nums'] },
  wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: S.sm },
  food: {
    minHeight: 44,
    borderWidth: 1,
    borderColor: C.fieldBorder,
    backgroundColor: C.field,
    borderRadius: 14,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  link: { color: C.accent, fontWeight: '700', fontSize: 14, paddingVertical: 12 },
  dayCell: { flex: 1, alignItems: 'center', gap: 6, paddingTop: 8, paddingBottom: 10, borderRadius: 16, backgroundColor: C.card },
  dayName: { fontSize: 11, fontWeight: '700', color: C.muted },
  dayNum: { fontSize: 16, fontWeight: '800', color: C.ink },
  mini: { flex: 1, backgroundColor: C.card, borderRadius: R.lg, padding: 14, gap: 8 },
  miniBtn: { minHeight: 44, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
});
