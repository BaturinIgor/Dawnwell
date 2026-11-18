import { Pressable, StyleSheet, Text } from 'react-native';

import { Row } from '@/components/ui';
import { C, S } from '@/constants/theme';

export function Stepper({
  value,
  unit,
  step,
  min,
  max,
  onChange,
}: {
  value: number;
  unit: string;
  step: number;
  min: number;
  max: number;
  onChange: (v: number) => void;
}) {
  return (
    <Row style={{ gap: S.sm }}>
      <Pressable accessibilityRole="button" accessibilityLabel="Decrease" onPress={() => onChange(Math.max(min, value - step))} style={st.step}>
        <Text style={st.stepText}>−</Text>
      </Pressable>
      <Text style={{ minWidth: 64, textAlign: 'center', fontSize: 17, fontWeight: '800', color: C.ink }}>
        {value} {unit}
      </Text>
      <Pressable accessibilityRole="button" accessibilityLabel="Increase" onPress={() => onChange(Math.min(max, value + step))} style={st.step}>
        <Text style={st.stepText}>+</Text>
      </Pressable>
    </Row>
  );
}

const st = StyleSheet.create({
  step: { width: 44, height: 44, borderRadius: 12, backgroundColor: C.neutralSoft, alignItems: 'center', justifyContent: 'center' },
  stepText: { fontSize: 20, fontWeight: '700', color: C.ink },
});
