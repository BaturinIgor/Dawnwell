import { Share, StyleSheet, Text, TextInput, View } from 'react-native';

import { Button, Card, Divider, Row, Screen, T } from '@/components/ui';
import { APP_NAME, C, R, S } from '@/constants/theme';
import { SYMPTOMS, medicationLabel } from '@/lib/catalog';
import { dayKey, lastDays, shortDate } from '@/lib/date';
import { proteinOf, useStore } from '@/lib/store';
import { AppData, SymptomId } from '@/lib/types';

const DAYS = 30;

function summarize(data: AppData) {
  const s = data.settings;
  const range = lastDays(DAYS);
  const logs = range.map((d) => data.days[dayKey(d)]).filter((x) => x !== undefined);
  const taken = logs.filter((l) => l.takenAt).length;
  const skipped = logs.filter((l) => l.skipped).length;
  const withFood = logs.filter((l) => l.foods.length > 0);
  const avgProtein = withFood.length ? Math.round(withFood.reduce((a, l) => a + proteinOf(l), 0) / withFood.length) : null;
  const withWater = logs.filter((l) => l.water > 0);
  const avgWater = withWater.length ? withWater.reduce((a, l) => a + l.water, 0) / withWater.length : null;

  const from = dayKey(range[0]);
  const weights = [...data.weights].filter((w) => w.date >= from).sort((a, b) => a.date.localeCompare(b.date));
  const weightChange = weights.length >= 2 ? weights[weights.length - 1].value - weights[0].value : null;

  const symptoms = SYMPTOMS.filter((x) => x.id !== 'good')
    .map((x) => {
      const hits = logs.flatMap((l) => l.symptoms.filter((e) => e.id === x.id));
      const worst = hits.reduce((m, e) => Math.max(m, e.severity), 0);
      const notes = hits.map((e) => e.note).filter(Boolean);
      return { id: x.id as SymptomId, label: x.label, days: hits.length, worst, notes };
    })
    .filter((x) => x.days > 0)
    .sort((a, b) => b.days - a.days);

  return {
    medication: medicationLabel(s.medication),
    dose: s.doseLabel,
    range: `${shortDate(range[0])} – ${shortDate(range[range.length - 1])}`,
    taken,
    skipped,
    avgProtein,
    avgWater,
    weights,
    weightChange,
    symptoms,
    doseHistory: data.doseHistory,
  };
}

function asText(r: ReturnType<typeof summarize>, questions: string, target: number): string {
  const lines = [
    `${APP_NAME} visit summary, ${r.range}`,
    '',
    `Medication: ${r.medication}${r.dose ? `, ${r.dose} daily` : ''}`,
    `Tablet logged taken on ${r.taken} of ${DAYS} days${r.skipped ? `, skipped ${r.skipped}` : ''}`,
  ];
  if (r.weightChange !== null)
    lines.push(`Weight: ${r.weights[0].value} → ${r.weights[r.weights.length - 1].value} lb (${r.weightChange > 0 ? '+' : ''}${r.weightChange.toFixed(1)})`);
  if (r.avgProtein !== null) lines.push(`Protein: ${r.avgProtein} g a day on average (target ${target} g)`);
  if (r.avgWater !== null) lines.push(`Water: ${r.avgWater.toFixed(1)} glasses a day on average`);
  lines.push('', 'Symptoms:');
  if (r.symptoms.length === 0) lines.push('- None logged');
  for (const x of r.symptoms) {
    lines.push(`- ${x.label}: ${x.days} day${x.days === 1 ? '' : 's'}, worst ${x.worst}/5`);
    for (const n of x.notes.slice(0, 3)) lines.push(`  "${n}"`);
  }
  if (r.doseHistory.length) {
    lines.push('', 'Dose history:');
    for (const d of r.doseHistory) lines.push(`- ${d.label} from ${d.from}`);
  }
  if (questions.trim()) lines.push('', 'My questions:', questions.trim());
  lines.push('', `Recorded by the patient in ${APP_NAME}. Not medical advice.`);
  return lines.join('\n');
}

export default function Report() {
  const { data, update } = useStore();
  const r = summarize(data);

  const share = () => {
    Share.share({ message: asText(r, data.questions, data.settings.proteinTarget) }).catch(() => {});
  };

  return (
    <Screen>
      <View style={{ gap: 4 }}>
        <T variant="title">Visit summary</T>
        <T variant="label">Last {DAYS} days · {r.range}</T>
      </View>

      <Card>
        <T variant="label">{r.medication}</T>
        <T variant="h2">{r.dose ? `${r.dose} daily` : 'Dose not set'}</T>
        <Divider />
        <View style={styles.stats}>
          <Stat value={`${r.taken}/${DAYS}`} label="Days taken" />
          <Stat
            value={r.weightChange === null ? '–' : `${r.weightChange > 0 ? '+' : ''}${r.weightChange.toFixed(1)}`}
            label="Weight, lb"
          />
          <Stat value={r.avgProtein === null ? '–' : `${r.avgProtein} g`} label="Protein a day" />
        </View>
      </Card>

      <Card>
        <T variant="h2">Symptoms</T>
        {r.symptoms.length === 0 ? (
          <T variant="small">No symptoms logged in this period.</T>
        ) : (
          r.symptoms.map((x) => (
            <View key={x.id} style={{ gap: 4 }}>
              <Row style={{ justifyContent: 'space-between' }}>
                <T style={{ fontWeight: '700' }}>{x.label}</T>
                <Text style={[styles.sev, x.worst >= 4 && { backgroundColor: C.warmSoft, color: C.warmInk }]}>
                  {x.days} day{x.days === 1 ? '' : 's'} · worst {x.worst}/5
                </Text>
              </Row>
              {x.notes.slice(0, 2).map((n, i) => (
                <T key={i} variant="small">
                  “{n}”
                </T>
              ))}
            </View>
          ))
        )}
      </Card>

      <View style={{ gap: S.sm }}>
        <T variant="h2" nativeID="questions">
          Questions for my clinician
        </T>
        <TextInput
          accessibilityLabelledBy="questions"
          value={data.questions}
          onChangeText={(q) => update((d) => ({ ...d, questions: q }))}
          placeholder="e.g. Is the nausea after dinner normal?"
          placeholderTextColor={C.muted}
          multiline
          style={styles.note}
        />
      </View>

      <Button title="Share summary" onPress={share} />
      <T variant="small" style={{ textAlign: 'center' }}>
        Send it to yourself or your care team before the visit.
      </T>
    </Screen>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <View style={{ flex: 1, gap: 2 }}>
      <Text style={{ fontSize: 22, fontWeight: '800', color: C.ink }}>{value}</Text>
      <T variant="small">{label}</T>
    </View>
  );
}

const styles = StyleSheet.create({
  stats: { flexDirection: 'row', gap: S.md },
  sev: {
    fontSize: 12,
    fontWeight: '700',
    color: C.inkSoft,
    backgroundColor: C.neutralSoft,
    borderRadius: R.pill,
    paddingHorizontal: 10,
    paddingVertical: 4,
    overflow: 'hidden',
  },
  note: {
    minHeight: 110,
    borderRadius: R.md,
    borderWidth: 1.5,
    borderColor: C.fieldBorder,
    backgroundColor: C.card,
    padding: 14,
    fontSize: 15,
    color: C.ink,
    textAlignVertical: 'top',
  },
});
