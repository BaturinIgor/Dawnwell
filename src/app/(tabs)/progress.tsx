import { useState } from 'react';
import { StyleSheet, Text, TextInput, useWindowDimensions, View } from 'react-native';
import Svg, { Circle, Line, Path } from 'react-native-svg';

import { Button, Card, Row, Screen, T } from '@/components/ui';
import { C, R, S } from '@/constants/theme';
import { dayKey, lastDays, parseDay, shortDate, weekdayShort } from '@/lib/date';
import { proteinOf, useStore } from '@/lib/store';
import { WeightEntry } from '@/lib/types';

function WeightChart({ points, width, goal }: { points: WeightEntry[]; width: number; goal: number | null }) {
  const h = 140;
  const pad = 10;
  const values = points.map((p) => p.value);
  if (goal !== null) values.push(goal);
  const min = Math.min(...values) - 1;
  const max = Math.max(...values) + 1;
  const x = (i: number) => pad + (points.length === 1 ? (width - pad * 2) / 2 : (i * (width - pad * 2)) / (points.length - 1));
  const y = (v: number) => pad + ((max - v) / (max - min)) * (h - pad * 2);
  const d = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(p.value).toFixed(1)}`).join(' ');
  return (
    <Svg width={width} height={h}>
      {goal !== null ? (
        <Line x1={pad} x2={width - pad} y1={y(goal)} y2={y(goal)} stroke={C.accent} strokeDasharray="4 6" strokeWidth={1.5} opacity={0.5} />
      ) : null}
      <Path d={d} stroke={C.accent} strokeWidth={3} fill="none" strokeLinejoin="round" strokeLinecap="round" />
      {points.map((p, i) => (
        <Circle key={p.date} cx={x(i)} cy={y(p.value)} r={i === points.length - 1 ? 5 : 3} fill={i === points.length - 1 ? C.accent : C.card} stroke={C.accent} strokeWidth={2} />
      ))}
    </Svg>
  );
}

export default function Progress() {
  const { data, update } = useStore();
  const s = data.settings;
  const { width } = useWindowDimensions();
  const [input, setInput] = useState('');

  const weights = [...data.weights].sort((a, b) => a.date.localeCompare(b.date));
  const latest = weights.at(-1);
  const start = s.startWeight ?? weights[0]?.value ?? null;
  const lost = latest && start !== null ? start - latest.value : null;
  const toGo = latest && s.goalWeight !== null ? latest.value - s.goalWeight : null;

  const logWeight = () => {
    const v = parseFloat(input.replace(',', '.'));
    if (!Number.isFinite(v) || v <= 0) return;
    const key = dayKey();
    update((d) => ({ ...d, weights: [...d.weights.filter((w) => w.date !== key), { date: key, value: v }] }));
    setInput('');
  };

  const week = lastDays(7);
  const proteinWeek = week.map((d) => {
    const log = data.days[dayKey(d)];
    return log ? proteinOf(log) : 0;
  });
  const maxProtein = Math.max(s.proteinTarget, ...proteinWeek);
  const hitDays = proteinWeek.filter((p) => p >= s.proteinTarget).length;

  const month = lastDays(28);
  const taken = month.filter((d) => data.days[dayKey(d)]?.takenAt).length;

  const noise = lastDays(14)
    .map((d) => data.days[dayKey(d)]?.foodNoise ?? null)
    .filter((n): n is number => n !== null);
  const half = Math.floor(noise.length / 2);
  const avg = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
  const noiseBefore = avg(noise.slice(0, half));
  const noiseNow = avg(noise.slice(half));

  const chartWidth = width - S.xl * 2 - S.xl * 2;

  return (
    <Screen>
      <T variant="title">Progress</T>

      <Card>
        <Row style={{ justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <View>
            <T variant="label">Weight</T>
            <T variant="big">{latest ? `${latest.value} lb` : '–'}</T>
            {latest ? <T variant="small">Logged {shortDate(parseDay(latest.date))}</T> : null}
          </View>
          <View style={{ alignItems: 'flex-end', gap: 4 }}>
            {lost !== null && lost !== 0 ? (
              <View style={styles.badge}>
                <Text style={styles.badgeText}>
                  {lost > 0 ? '−' : '+'}
                  {Math.abs(lost).toFixed(1)} lb since start
                </Text>
              </View>
            ) : null}
            {toGo !== null && toGo > 0 ? <T variant="small">{toGo.toFixed(1)} lb to goal</T> : null}
          </View>
        </Row>
        {weights.length > 0 ? (
          <WeightChart points={weights.slice(-12)} width={chartWidth} goal={s.goalWeight} />
        ) : (
          <T variant="small">Log your weight once a week, same time of day, to see your trend.</T>
        )}
        <Row style={{ gap: S.sm }}>
          <TextInput
            accessibilityLabel="Today's weight in pounds"
            value={input}
            onChangeText={setInput}
            keyboardType="decimal-pad"
            placeholder="Today's weight, lb"
            placeholderTextColor={C.muted}
            style={[styles.input, { flex: 1, minWidth: 0 }]}
          />
          <Button title="Log" onPress={logWeight} />
        </Row>
      </Card>

      <Card>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="h2">Protein this week</T>
          <T variant="small" style={{ fontWeight: '700' }}>
            {hitDays} of 7 days at {s.proteinTarget} g
          </T>
        </Row>
        <View style={styles.bars}>
          {week.map((d, i) => {
            const p = proteinWeek[i];
            const hit = p >= s.proteinTarget;
            return (
              <View key={dayKey(d)} style={{ flex: 1, alignItems: 'center', gap: 6 }}>
                <View style={styles.barTrack}>
                  <View
                    style={{
                      height: `${Math.max(4, (p / maxProtein) * 100)}%`,
                      borderRadius: 8,
                      backgroundColor: hit ? C.accent : p > 0 ? C.warmLight : C.lineSoft,
                    }}
                  />
                </View>
                <Text style={styles.barLabel}>{weekdayShort(d)}</Text>
              </View>
            );
          })}
        </View>
        <T variant="small">Enough protein helps you keep muscle while you lose weight.</T>
      </Card>

      <Card>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="h2">Tablet, last 4 weeks</T>
          <T variant="small" style={{ fontWeight: '700' }}>
            {taken} of 28
          </T>
        </Row>
        <View style={styles.grid}>
          {month.map((d) => {
            const log = data.days[dayKey(d)];
            const isToday = dayKey(d) === dayKey();
            const bg = log?.takenAt ? C.accent : log?.skipped ? C.warmLight : C.lineSoft;
            return (
              <View
                key={dayKey(d)}
                accessibilityLabel={`${shortDate(d)}: ${log?.takenAt ? 'taken' : log?.skipped ? 'skipped' : 'not logged'}`}
                style={[styles.cell, { backgroundColor: bg }, isToday && { borderWidth: 2, borderColor: C.ink }]}
              />
            );
          })}
        </View>
        <Row style={{ gap: S.lg }}>
          <Legend color={C.accent} label="Taken" />
          <Legend color={C.warmLight} label="Skipped" />
          <Legend color={C.lineSoft} label="Not logged" />
        </Row>
      </Card>

      <Card>
        <T variant="h2">Food noise</T>
        {noiseNow === null ? (
          <T variant="small">Rate your food noise on Today. After a few days you will see the trend here.</T>
        ) : (
          <>
            <Row style={{ alignItems: 'flex-end' }}>
              <T variant="big">{noiseNow.toFixed(1)}</T>
              <T variant="label" style={{ marginBottom: 6 }}>
                of 5, recent average
              </T>
            </Row>
            {noiseBefore !== null ? (
              <T variant="small">
                {noiseNow < noiseBefore
                  ? `Quieter than the week before (${noiseBefore.toFixed(1)}).`
                  : noiseNow > noiseBefore
                    ? `Louder than the week before (${noiseBefore.toFixed(1)}).`
                    : 'About the same as the week before.'}
              </T>
            ) : null}
          </>
        )}
      </Card>
    </Screen>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <Row style={{ gap: 6 }}>
      <View style={{ width: 12, height: 12, borderRadius: 4, backgroundColor: color }} />
      <T variant="small">{label}</T>
    </Row>
  );
}

const styles = StyleSheet.create({
  badge: { backgroundColor: C.accentSoft, borderRadius: R.pill, paddingHorizontal: S.md, paddingVertical: 6 },
  badgeText: { color: C.accentDark, fontWeight: '800', fontSize: 13 },
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
  bars: { flexDirection: 'row', gap: S.sm, height: 140 },
  barTrack: { flex: 1, width: '100%', justifyContent: 'flex-end' },
  barLabel: { fontSize: 12, fontWeight: '600', color: C.muted },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  cell: { width: '12%', aspectRatio: 1, borderRadius: 8 },
});
