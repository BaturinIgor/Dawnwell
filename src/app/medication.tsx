import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, StyleSheet, Switch, Text, TextInput, View } from 'react-native';

import { Stepper } from '@/components/stepper';
import { Button, Card, Divider, Row, Screen, T } from '@/components/ui';
import { C, R, S } from '@/constants/theme';
import { MEDICATIONS, REFILL_AT, medicationLabel } from '@/lib/catalog';
import { clockLabel, dayKey, parseDay, shortDate } from '@/lib/date';
import { useStore } from '@/lib/store';
import { MedicationId, Reminders } from '@/lib/types';

export default function Medication() {
  const { data, update, updateSettings } = useStore();
  const s = data.settings;
  const [editing, setEditing] = useState(false);
  const [dose, setDose] = useState(s.doseLabel);
  const [med, setMed] = useState<MedicationId>(s.medication);
  const [count, setCount] = useState('');

  const saveTablet = () => {
    const label = dose.trim();
    update((d) => {
      const changed = label && label !== d.settings.doseLabel;
      return {
        ...d,
        settings: { ...d.settings, medication: med, doseLabel: label },
        doseHistory: changed ? [...d.doseHistory, { label: `${label} daily`, from: dayKey() }] : d.doseHistory,
      };
    });
    setEditing(false);
  };

  const setTime = (deltaMin: number) => {
    const total = (s.doseHour * 60 + s.doseMinute + deltaMin + 24 * 60) % (24 * 60);
    updateSettings({ doseHour: Math.floor(total / 60), doseMinute: total % 60 });
  };

  const refill = () => {
    const n = parseInt(count, 10);
    if (!Number.isFinite(n) || n <= 0) return;
    updateSettings({ tabletsLeft: (s.tabletsLeft ?? 0) + n });
    setCount('');
  };

  const low = s.tabletsLeft !== null && s.tabletsLeft <= REFILL_AT;
  const history = [...data.doseHistory].reverse();

  return (
    <Screen>
      <Row style={{ justifyContent: 'space-between' }}>
        <Pressable accessibilityRole="button" accessibilityLabel="Back" onPress={() => router.back()} style={styles.back}>
          <Text style={{ fontSize: 20, color: C.ink }}>‹</Text>
        </Pressable>
        <T variant="h2">Medication</T>
        <View style={{ width: 44 }} />
      </Row>

      <View style={styles.hero}>
        <Text style={styles.heroLabel}>Your tablet</Text>
        <Text style={styles.heroTitle}>{medicationLabel(s.medication)}</Text>
        <Text style={styles.heroSub}>
          {s.doseLabel ? `${s.doseLabel} · ` : ''}every day at {clockLabel(s.doseHour, s.doseMinute)}
        </Text>
        {!editing ? (
          <Button title="Update from my label" kind="light" onPress={() => setEditing(true)} style={{ marginTop: S.sm }} />
        ) : null}
      </View>

      {editing ? (
        <Card>
          <T variant="h2" style={{ fontSize: 15 }}>
            Copy from your prescription label
          </T>
          {MEDICATIONS.map((m) => (
            <Pressable
              key={m.id}
              accessibilityRole="radio"
              accessibilityState={{ checked: med === m.id }}
              onPress={() => setMed(m.id)}
              style={[styles.option, { borderColor: med === m.id ? C.accent : C.line }]}>
              <Text style={styles.optionText}>{m.label}</Text>
              <View style={[styles.radio, med === m.id && { borderWidth: 7, borderColor: C.accent }]} />
            </Pressable>
          ))}
          <TextInput
            accessibilityLabel="Dose on your label"
            value={dose}
            onChangeText={setDose}
            placeholder="Dose, e.g. 7 mg"
            placeholderTextColor={C.muted}
            style={styles.input}
          />
          <T variant="small">Only change this when your prescriber changes your dose.</T>
          <Row>
            <Button title="Cancel" kind="secondary" onPress={() => setEditing(false)} style={{ flex: 1 }} />
            <Button title="Save" onPress={saveTablet} style={{ flex: 1 }} />
          </Row>
        </Card>
      ) : null}

      <Card>
        <Row style={{ justifyContent: 'space-between' }}>
          <View style={{ flex: 1 }}>
            <T variant="h2" style={{ fontSize: 15 }}>
              Usual time
            </T>
            <T variant="small">Your tablet reminder follows this</T>
          </View>
          <Row style={{ gap: S.sm }}>
            <Pressable accessibilityRole="button" accessibilityLabel="15 minutes earlier" onPress={() => setTime(-15)} style={styles.step}>
              <Text style={styles.stepText}>−</Text>
            </Pressable>
            <Text style={styles.timeText}>{clockLabel(s.doseHour, s.doseMinute)}</Text>
            <Pressable accessibilityRole="button" accessibilityLabel="15 minutes later" onPress={() => setTime(15)} style={styles.step}>
              <Text style={styles.stepText}>+</Text>
            </Pressable>
          </Row>
        </Row>
        <Divider />
        <Row style={{ justifyContent: 'space-between' }}>
          <View style={{ flex: 1 }}>
            <T variant="h2" style={{ fontSize: 15 }}>
              Wait before eating
            </T>
            <T variant="small">As written on your label</T>
          </View>
          <Stepper value={s.waitMinutes} unit="min" step={5} min={5} max={120} onChange={(v) => updateSettings({ waitMinutes: v })} />
        </Row>
      </Card>

      <Card style={low ? { backgroundColor: C.warmSoft } : undefined}>
        <Row style={{ justifyContent: 'space-between' }}>
          <View style={{ flex: 1 }}>
            <T variant="h2" style={{ fontSize: 15 }}>
              Tablets left
            </T>
            <T variant="small" style={low ? { color: C.warmInk } : undefined}>
              {s.tabletsLeft === null
                ? 'Add your pack to get a refill heads-up'
                : low
                  ? 'Time to ask for a refill'
                  : `About ${s.tabletsLeft} days left`}
            </T>
          </View>
          <Text style={[styles.count, low && { color: C.warmDark }]}>{s.tabletsLeft ?? '–'}</Text>
        </Row>
        <Row style={{ gap: S.sm }}>
          <TextInput
            accessibilityLabel="Tablets in new pack"
            value={count}
            onChangeText={setCount}
            keyboardType="number-pad"
            placeholder="Tablets in new pack"
            placeholderTextColor={C.muted}
            style={[styles.input, { flex: 1, minWidth: 0 }]}
          />
          <Button title="Add" kind="secondary" onPress={refill} />
        </Row>
      </Card>

      <Card style={{ paddingVertical: S.xs }}>
        {(
          [
            ['tablet', 'Tablet reminder', `Every day at ${clockLabel(s.doseHour, s.doseMinute)}`],
            ['waitOver', 'Wait is over', 'Tells you when you can eat'],
            ['protein', 'Protein check', 'At 3 PM'],
            ['refill', 'Refill heads-up', `Shown on Today at ${REFILL_AT} tablets`],
          ] as [keyof Reminders, string, string][]
        ).map(([k, label, sub]) => (
          <Row key={k} style={{ justifyContent: 'space-between', minHeight: 60 }}>
            <View style={{ flex: 1 }}>
              <T style={{ fontWeight: '700' }}>{label}</T>
              <T variant="small">{sub}</T>
            </View>
            <Switch
              accessibilityLabel={label}
              value={s.reminders[k]}
              onValueChange={(v) => updateSettings({ reminders: { ...s.reminders, [k]: v } })}
              trackColor={{ true: C.accent, false: '#C9D0C8' }}
            />
          </Row>
        ))}
      </Card>

      <View style={{ gap: S.sm }}>
        <T variant="label" style={{ color: C.inkSoft, fontWeight: '700' }}>
          Dose history
        </T>
        <Card style={{ gap: S.sm }}>
          {history.length === 0 ? (
            <T variant="small">Your dose changes will show here, for your visit summary.</T>
          ) : (
            history.map((h, i) => (
              <Row key={`${h.from}-${i}`} style={{ justifyContent: 'space-between' }}>
                <T style={{ fontWeight: i === 0 ? '700' : '400' }}>{h.label}</T>
                <T variant="small">
                  {i === 0 ? 'Since ' : 'From '}
                  {shortDate(parseDay(h.from))}
                </T>
              </Row>
            ))
          )}
        </Card>
      </View>

      <T variant="small" style={{ textAlign: 'center' }}>
        Dawnwell only records what your prescriber set. Talk to them before changing anything.
      </T>
    </Screen>
  );
}

const styles = StyleSheet.create({
  back: { width: 44, height: 44, borderRadius: 22, backgroundColor: C.card, alignItems: 'center', justifyContent: 'center' },
  hero: { backgroundColor: C.accent, borderRadius: R.xl, padding: S.xxl, gap: 6 },
  heroLabel: { color: C.white, opacity: 0.8, fontSize: 13, fontWeight: '700' },
  heroTitle: { color: C.white, fontSize: 26, fontWeight: '800', letterSpacing: -0.4 },
  heroSub: { color: C.white, opacity: 0.9, fontSize: 15 },
  option: {
    minHeight: 52,
    borderRadius: R.md,
    borderWidth: 2,
    backgroundColor: C.card,
    paddingHorizontal: S.lg,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  optionText: { fontSize: 15, fontWeight: '700', color: C.ink },
  radio: { width: 22, height: 22, borderRadius: 11, borderWidth: 2, borderColor: '#B9C2BB' },
  input: {
    minHeight: 52,
    borderRadius: R.md,
    borderWidth: 1.5,
    borderColor: C.fieldBorder,
    backgroundColor: C.card,
    paddingHorizontal: S.lg,
    fontSize: 15,
    color: C.ink,
  },
  step: { width: 40, height: 40, borderRadius: 20, backgroundColor: C.neutralSoft, alignItems: 'center', justifyContent: 'center' },
  stepText: { fontSize: 20, fontWeight: '700', color: C.ink },
  timeText: { fontSize: 15, fontWeight: '800', color: C.ink, minWidth: 72, textAlign: 'center' },
  count: { fontSize: 30, fontWeight: '800', color: C.ink },
});
