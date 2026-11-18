import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, StyleSheet, Switch, Text, TextInput, View } from 'react-native';

import { Stepper } from '@/components/stepper';
import { Button, Card, Row, Screen, T } from '@/components/ui';
import { APP_NAME, C, R, S } from '@/constants/theme';
import { MEDICATIONS } from '@/lib/catalog';
import { clockLabel, dayKey } from '@/lib/date';
import { ensurePermission } from '@/lib/notifications';
import { defaultSettings, useStore } from '@/lib/store';
import { MedicationId, Reminders } from '@/lib/types';

const TIMES: [number, number][] = [
  [6, 30],
  [7, 0],
  [7, 30],
  [8, 0],
];

export default function Onboarding() {
  const { update } = useStore();
  const [step, setStep] = useState(0);
  const [med, setMed] = useState<MedicationId>('oral-semaglutide');
  const [dose, setDose] = useState('');
  const [time, setTime] = useState<[number, number]>([7, 0]);
  const [wait, setWait] = useState(30);
  const [weight, setWeight] = useState('');
  const [goal, setGoal] = useState('');
  const [protein, setProtein] = useState(100);
  const [reminders, setReminders] = useState<Reminders>(defaultSettings.reminders);

  const finish = async () => {
    const start = parseFloat(weight);
    const target = parseFloat(goal);
    update((d) => ({
      ...d,
      settings: {
        ...d.settings,
        onboarded: true,
        medication: med,
        doseLabel: dose.trim(),
        doseHour: time[0],
        doseMinute: time[1],
        waitMinutes: wait,
        proteinTarget: protein,
        startWeight: Number.isFinite(start) ? start : null,
        goalWeight: Number.isFinite(target) ? target : null,
        reminders,
      },
      weights: Number.isFinite(start) ? [{ date: dayKey(), value: start }] : d.weights,
      doseHistory: dose.trim() ? [{ label: `${dose.trim()} daily`, from: dayKey() }] : d.doseHistory,
    }));
    if (reminders.tablet || reminders.waitOver || reminders.protein) await ensurePermission().catch(() => false);
    router.replace('/');
  };

  return (
    <Screen>
      <Row>
        {step > 0 ? (
          <Pressable accessibilityRole="button" accessibilityLabel="Back" onPress={() => setStep(step - 1)} style={styles.back}>
            <Text style={{ fontSize: 20, color: C.ink }}>‹</Text>
          </Pressable>
        ) : null}
        {step > 0 ? (
          <View style={{ flex: 1, flexDirection: 'row', gap: 6 }}>
            {[1, 2].map((i) => (
              <View key={i} style={[styles.bar, { backgroundColor: step >= i ? C.accent : C.fieldBorder }]} />
            ))}
          </View>
        ) : null}
      </Row>

      {step === 0 ? (
        <View style={{ gap: S.xl }}>
          <View style={styles.welcome}>
            <Text style={styles.brand}>{APP_NAME}</Text>
            <Text style={styles.welcomeTitle}>Your daily GLP-1 tablet, made simple</Text>
          </View>
          {[
            'Know exactly when you can eat after your tablet',
            'Hit your protein to keep your muscle',
            'Bring a clear summary to every visit',
          ].map((line) => (
            <Row key={line}>
              <View style={styles.check}>
                <Text style={{ color: C.accent, fontWeight: '800' }}>✓</Text>
              </View>
              <T style={{ flex: 1, color: C.inkSoft }}>{line}</T>
            </Row>
          ))}
          <Button title="Get started" onPress={() => setStep(1)} />
          <T variant="small" style={{ textAlign: 'center' }}>
            {APP_NAME} records what you log. It does not give medical advice or change your dose.
          </T>
        </View>
      ) : null}

      {step === 1 ? (
        <View style={{ gap: S.lg }}>
          <View style={{ gap: 6 }}>
            <T variant="title">Your tablet</T>
            <T variant="label">Copy these from your prescription label. You can change them anytime.</T>
          </View>
          <View style={{ gap: S.sm }}>
            <T variant="label" style={styles.fieldLabel}>
              Medication
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
          </View>
          <View style={{ gap: S.sm }}>
            <T variant="label" style={styles.fieldLabel} nativeID="doseLabel">
              Dose on your label
            </T>
            <TextInput
              accessibilityLabelledBy="doseLabel"
              value={dose}
              onChangeText={setDose}
              placeholder="e.g. 7 mg"
              placeholderTextColor={C.muted}
              style={styles.input}
            />
          </View>
          <View style={{ gap: S.sm }}>
            <T variant="label" style={styles.fieldLabel}>
              Usual time
            </T>
            <View style={{ flexDirection: 'row', gap: S.sm }}>
              {TIMES.map(([h, m]) => {
                const on = time[0] === h && time[1] === m;
                return (
                  <Pressable
                    key={`${h}:${m}`}
                    accessibilityRole="button"
                    accessibilityState={{ selected: on }}
                    onPress={() => setTime([h, m])}
                    style={[styles.time, on && { backgroundColor: C.accent, borderColor: C.accent }]}>
                    <Text style={{ fontWeight: '700', color: on ? C.white : C.ink }}>{clockLabel(h, m).replace(' AM', '')}</Text>
                  </Pressable>
                );
              })}
            </View>
          </View>
          <Card style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: S.lg }}>
            <View style={{ flex: 1 }}>
              <T variant="h2" style={{ fontSize: 15 }}>
                Wait before eating
              </T>
              <T variant="small">As written on your label</T>
            </View>
            <Stepper value={wait} unit="min" step={5} min={5} max={120} onChange={setWait} />
          </Card>
          <Button title="Continue" onPress={() => setStep(2)} />
        </View>
      ) : null}

      {step === 2 ? (
        <View style={{ gap: S.lg }}>
          <View style={{ gap: 6 }}>
            <T variant="title">Goals and reminders</T>
            <T variant="label">Agree on your targets with your care team.</T>
          </View>
          <View style={{ flexDirection: 'row', gap: S.md }}>
            <View style={{ flex: 1, gap: S.sm }}>
              <T variant="label" style={styles.fieldLabel} nativeID="cw">
                Current weight (lb)
              </T>
              <TextInput accessibilityLabelledBy="cw" value={weight} onChangeText={setWeight} keyboardType="decimal-pad" placeholder="195" placeholderTextColor={C.muted} style={styles.input} />
            </View>
            <View style={{ flex: 1, gap: S.sm }}>
              <T variant="label" style={styles.fieldLabel} nativeID="gw">
                Goal weight (lb)
              </T>
              <TextInput accessibilityLabelledBy="gw" value={goal} onChangeText={setGoal} keyboardType="decimal-pad" placeholder="170" placeholderTextColor={C.muted} style={styles.input} />
            </View>
          </View>
          <Card style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: S.lg }}>
            <View style={{ flex: 1 }}>
              <T variant="h2" style={{ fontSize: 15 }}>
                Daily protein
              </T>
              <T variant="small">Change it anytime</T>
            </View>
            <Stepper value={protein} unit="g" step={5} min={40} max={200} onChange={setProtein} />
          </Card>
          <Card style={{ paddingVertical: S.xs }}>
            {(
              [
                ['tablet', 'Tablet reminder', `Every day at ${clockLabel(time[0], time[1])}`],
                ['waitOver', 'Wait is over', 'Tells you when you can eat'],
                ['protein', 'Protein check', 'At 3 PM'],
              ] as [keyof Reminders, string, string][]
            ).map(([k, label, sub]) => (
              <Row key={k} style={{ justifyContent: 'space-between', minHeight: 60 }}>
                <View style={{ flex: 1 }}>
                  <T style={{ fontWeight: '700' }}>{label}</T>
                  <T variant="small">{sub}</T>
                </View>
                <Switch
                  accessibilityLabel={label}
                  value={reminders[k]}
                  onValueChange={(v) => setReminders({ ...reminders, [k]: v })}
                  trackColor={{ true: C.accent, false: '#C9D0C8' }}
                />
              </Row>
            ))}
          </Card>
          <Button title="Finish setup" onPress={finish} />
        </View>
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  back: { width: 44, height: 44, borderRadius: 22, backgroundColor: C.card, alignItems: 'center', justifyContent: 'center' },
  bar: { flex: 1, height: 6, borderRadius: 3 },
  welcome: { backgroundColor: C.accent, borderRadius: R.xl + 8, padding: S.xxl, paddingTop: 80, gap: S.md },
  brand: { color: C.white, fontSize: 18, fontWeight: '800', opacity: 0.9 },
  welcomeTitle: { color: C.white, fontSize: 32, fontWeight: '800', lineHeight: 38, letterSpacing: -0.5 },
  check: { width: 28, height: 28, borderRadius: 14, backgroundColor: C.accentSoft, alignItems: 'center', justifyContent: 'center' },
  fieldLabel: { color: C.inkSoft, fontWeight: '700' },
  option: {
    minHeight: 56,
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
    fontSize: 16,
    fontWeight: '600',
    color: C.ink,
  },
  time: { flex: 1, minHeight: 48, borderRadius: 14, borderWidth: 1.5, borderColor: C.fieldBorder, backgroundColor: C.card, alignItems: 'center', justifyContent: 'center' },
});
