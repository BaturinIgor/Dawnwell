import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { Button, Card, Chip, Row, Scale, Screen, T } from '@/components/ui';
import { C, R, S } from '@/constants/theme';
import { SEVERITY_WORDS, SYMPTOMS, TRIGGERS, symptomLabel } from '@/lib/catalog';
import { dayKey } from '@/lib/date';
import { useStore } from '@/lib/store';
import { SymptomId } from '@/lib/types';

export default function Symptom() {
  const { data, updateDay } = useStore();
  const existing = data.days[dayKey()]?.symptoms ?? [];
  const firstBad = existing.find((x) => x.id !== 'good');
  const [id, setId] = useState<SymptomId>(firstBad?.id ?? 'nausea');
  const current = existing.find((x) => x.id === id);
  const [severity, setSeverity] = useState<number>(current?.severity ?? 2);
  const [triggers, setTriggers] = useState<string[]>(current?.triggers ?? []);
  const [note, setNote] = useState(current?.note ?? '');

  const pick = (next: SymptomId) => {
    const e = existing.find((x) => x.id === next);
    setId(next);
    setSeverity(e?.severity ?? 2);
    setTriggers(e?.triggers ?? []);
    setNote(e?.note ?? '');
  };

  const save = () => {
    updateDay(dayKey(), (d) => ({
      ...d,
      symptoms: [...d.symptoms.filter((x) => x.id !== id), { id, severity, triggers, note: note.trim(), at: Date.now() }],
    }));
    router.back();
  };

  return (
    <Screen>
      <Row style={{ justifyContent: 'space-between' }}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close" onPress={() => router.back()} style={styles.close}>
          <Text style={{ fontSize: 18, color: C.ink }}>✕</Text>
        </Pressable>
        <T variant="label">Symptom details</T>
        <View style={{ width: 44 }} />
      </Row>

      <View style={styles.wrap}>
        {SYMPTOMS.filter((x) => x.id !== 'good').map((x) => (
          <Chip key={x.id} label={x.label} tone="warm" selected={id === x.id} onPress={() => pick(x.id)} />
        ))}
      </View>

      <T variant="title" style={{ lineHeight: 34 }}>
        How strong is the {symptomLabel(id).toLowerCase()}?
      </T>
      <Scale value={severity} onChange={setSeverity} words={SEVERITY_WORDS} />
      <Row style={{ justifyContent: 'space-between' }}>
        <T variant="small">Barely there</T>
        <T variant="small" style={{ fontWeight: '700' }}>
          {SEVERITY_WORDS[severity]}
        </T>
        <T variant="small">Severe</T>
      </Row>

      <T variant="h2" style={{ fontSize: 15 }}>
        Anything that might have caused it?
      </T>
      <View style={styles.wrap}>
        {TRIGGERS.map((t) => (
          <Chip
            key={t}
            label={t}
            selected={triggers.includes(t)}
            onPress={() => setTriggers(triggers.includes(t) ? triggers.filter((x) => x !== t) : [...triggers, t])}
          />
        ))}
      </View>

      <View style={{ gap: S.sm }}>
        <T variant="h2" style={{ fontSize: 15 }} nativeID="note">
          Note for your visit summary
        </T>
        <TextInput
          accessibilityLabelledBy="note"
          value={note}
          onChangeText={setNote}
          placeholder="What helped, what made it worse"
          placeholderTextColor={C.muted}
          multiline
          style={styles.note}
        />
      </View>

      {severity >= 4 ? (
        <Card style={{ backgroundColor: C.warmSoft }}>
          <Text style={{ color: C.warmInk, fontSize: 13, lineHeight: 19 }}>
            Severe or lasting symptoms, or strong stomach pain, are a reason to contact your clinician today.
          </Text>
        </Card>
      ) : null}

      <Button title="Save" onPress={save} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  close: { width: 44, height: 44, borderRadius: 22, backgroundColor: C.card, alignItems: 'center', justifyContent: 'center' },
  wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: S.sm },
  note: {
    minHeight: 96,
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
