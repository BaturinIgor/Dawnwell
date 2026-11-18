import { ReactNode } from 'react';
import {
  Pressable,
  PressableProps,
  ScrollView,
  StyleProp,
  StyleSheet,
  Text,
  TextProps,
  View,
  ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Svg, { Circle } from 'react-native-svg';

import { C, R, S } from '@/constants/theme';

export function Screen({ children, scroll = true }: { children: ReactNode; scroll?: boolean }) {
  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      {scroll ? (
        <ScrollView contentContainerStyle={styles.screenContent} keyboardShouldPersistTaps="handled">
          {children}
        </ScrollView>
      ) : (
        <View style={[styles.screenContent, { flex: 1 }]}>{children}</View>
      )}
    </SafeAreaView>
  );
}

export function Card({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

type TVariant = 'title' | 'h2' | 'body' | 'label' | 'small' | 'big';

export function T({ variant = 'body', style, ...rest }: TextProps & { variant?: TVariant }) {
  return <Text {...rest} style={[styles[variant], style]} />;
}

type BtnKind = 'primary' | 'secondary' | 'soft' | 'light';

export function Button({
  title,
  kind = 'primary',
  style,
  ...rest
}: PressableProps & { title: string; kind?: BtnKind; style?: StyleProp<ViewStyle> }) {
  const k = btnKinds[kind];
  return (
    <Pressable
      accessibilityRole="button"
      {...rest}
      style={({ pressed }) => [styles.btn, { backgroundColor: k.bg, borderColor: k.border }, pressed && { opacity: 0.85 }, style]}>
      <Text style={[styles.btnText, { color: k.fg }]}>{title}</Text>
    </Pressable>
  );
}

const btnKinds: Record<BtnKind, { bg: string; fg: string; border: string }> = {
  primary: { bg: C.accent, fg: C.white, border: C.accent },
  secondary: { bg: C.card, fg: C.ink, border: '#CBD3C9' },
  soft: { bg: C.neutralSoft, fg: C.ink, border: C.neutralSoft },
  light: { bg: C.white, fg: '#0B3D35', border: C.white },
};

export function Chip({
  label,
  selected,
  onPress,
  tone = 'accent',
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
  tone?: 'accent' | 'warm';
}) {
  const on = tone === 'warm' ? { bg: C.warmSoft, border: C.warmDark, fg: C.warmInk } : { bg: C.accentSoft, border: C.accent, fg: C.accentDark };
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      onPress={onPress}
      style={[
        styles.chip,
        selected ? { backgroundColor: on.bg, borderColor: on.border } : { backgroundColor: C.card, borderColor: C.fieldBorder },
      ]}>
      <Text style={[styles.chipText, { color: selected ? on.fg : C.ink }]}>{label}</Text>
    </Pressable>
  );
}

export function Ring({
  size,
  stroke,
  progress,
  color,
  track,
  children,
}: {
  size: number;
  stroke: number;
  progress: number;
  color: string;
  track: string;
  children?: ReactNode;
}) {
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const p = Math.max(0, Math.min(1, progress));
  return (
    <View style={{ width: size, height: size }}>
      <Svg width={size} height={size}>
        <Circle cx={size / 2} cy={size / 2} r={r} stroke={track} strokeWidth={stroke} fill="none" />
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke={color}
          strokeWidth={stroke}
          fill="none"
          strokeLinecap="round"
          strokeDasharray={`${circ} ${circ}`}
          strokeDashoffset={circ * (1 - p)}
          rotation={-90}
          origin={`${size / 2}, ${size / 2}`}
        />
      </Svg>
      {children ? <View style={[StyleSheet.absoluteFill, styles.center]}>{children}</View> : null}
    </View>
  );
}

export function Row({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.row, style]}>{children}</View>;
}

export function Divider() {
  return <View style={{ height: 1, backgroundColor: C.lineSoft }} />;
}

/** Five-step scale, used for severity and food noise. */
export function Scale({
  value,
  onChange,
  words,
}: {
  value: number | null;
  onChange: (v: number) => void;
  words: string[];
}) {
  return (
    <View style={styles.scale}>
      {[1, 2, 3, 4, 5].map((n) => {
        const on = value === n;
        const hot = n >= 4;
        const bg = on ? (hot ? C.warmDark : C.accent) : C.field;
        return (
          <Pressable
            key={n}
            accessibilityRole="button"
            accessibilityLabel={`${n}, ${words[n]}`}
            accessibilityState={{ selected: on }}
            onPress={() => onChange(n)}
            style={[styles.scaleItem, { backgroundColor: bg, borderColor: on ? bg : C.fieldBorder }]}>
            <View
              style={{
                width: 16,
                height: 8 + n * 5,
                borderRadius: 999,
                backgroundColor: on ? C.white : hot ? C.warm : C.accent,
              }}
            />
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: C.bg },
  screenContent: { padding: S.xl, paddingBottom: 48, gap: S.lg },
  card: { backgroundColor: C.card, borderRadius: R.xl - 4, padding: S.xl, gap: S.md },
  row: { flexDirection: 'row', alignItems: 'center', gap: S.md },
  center: { alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 28, fontWeight: '800', color: C.ink, letterSpacing: -0.5 },
  h2: { fontSize: 17, fontWeight: '800', color: C.ink },
  body: { fontSize: 15, lineHeight: 22, color: C.ink },
  label: { fontSize: 13, fontWeight: '600', color: C.muted },
  small: { fontSize: 12, lineHeight: 17, color: C.muted },
  big: { fontSize: 30, fontWeight: '800', color: C.ink, letterSpacing: -0.5 },
  btn: { minHeight: 52, borderRadius: R.md, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center', paddingHorizontal: S.xl },
  btnText: { fontSize: 16, fontWeight: '800' },
  chip: { minHeight: 44, borderRadius: R.pill, borderWidth: 1.5, paddingHorizontal: S.lg, justifyContent: 'center' },
  chipText: { fontSize: 14, fontWeight: '600' },
  scale: { flexDirection: 'row', gap: S.sm },
  scaleItem: { flex: 1, height: 52, borderRadius: 14, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center' },
});
