import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, Row, T } from '@/components/ui';
import { C, R, S } from '@/constants/theme';
import { FOODS } from '@/lib/catalog';
import { dayKey } from '@/lib/date';
import { newId, useStore } from '@/lib/store';
import { Meal } from '@/lib/types';

const MEALS: Meal[] = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

function mealNow(): Meal {
  const h = new Date().getHours();
  if (h < 11) return 'Breakfast';
  if (h < 16) return 'Lunch';
  if (h < 21) return 'Dinner';
  return 'Snack';
}

export default function LogFood() {
  const { updateDay } = useStore();
  const [meal, setMeal] = useState<Meal>(mealNow);
  const [query, setQuery] = useState('');
  const [picked, setPicked] = useState<Record<string, boolean>>({});
  const [customName, setCustomName] = useState('');
  const [customG, setCustomG] = useState('');

  const list = useMemo(() => {
    const q = query.trim().toLowerCase();
    return [...FOODS].filter((f) => !q || f.name.toLowerCase().includes(q)).sort((a, b) => b.protein - a.protein);
  }, [query]);

  const chosen = FOODS.filter((f) => picked[f.name]);
  const customGrams = parseInt(customG, 10);
  const hasCustom = customName.trim().length > 0 && Number.isFinite(customGrams) && customGrams > 0;
  const total = chosen.reduce((s, f) => s + f.protein, 0) + (hasCustom ? customGrams : 0);
  const count = chosen.length + (hasCustom ? 1 : 0);

  const save = () => {
    const at = Date.now();
    updateDay(dayKey(), (d) => ({
      ...d,
      foods: [
        ...d.foods,
        ...chosen.map((f) => ({ id: newId(), name: f.name, protein: f.protein, meal, at })),
        ...(hasCustom ? [{ id: newId(), name: customName.trim(), protein: customGrams, meal, at }] : []),
      ],
    }));
    router.back();
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top', 'bottom']}>
      <View style={{ padding: S.xl, gap: S.md }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <Pressable accessibilityRole="button" accessibilityLabel="Close" onPress={() => router.back()} style={styles.close}>
            <Text style={{ fontSize: 18, color: C.ink }}>✕</Text>
          </Pressable>
          <T variant="h2">Add food</T>
          <View style={{ width: 44 }} />
        </Row>
        <TextInput
          accessibilityLabel="Search foods"
          value={query}
          onChangeText={setQuery}
          placeholder="Search foods"
          placeholderTextColor={C.muted}
          style={styles.search}
        />
        <View style={styles.segment}>
          {MEALS.map((m) => (
            <Pressable
              key={m}
              accessibilityRole="button"
              accessibilityState={{ selected: meal === m }}
              onPress={() => setMeal(m)}
              style={[styles.segItem, meal === m && styles.segOn]}>
              <Text style={{ fontSize: 13, fontWeight: '700', color: C.ink }}>{m}</Text>
            </Pressable>
          ))}
        </View>
      </View>

      <FlatList
        data={list}
        keyExtractor={(f) => f.name}
        contentContainerStyle={{ paddingHorizontal: S.xl, paddingBottom: S.xl }}
        ListHeaderComponent={
          <View style={styles.tip}>
            <Text style={{ color: C.warmInk, fontSize: 13, lineHeight: 19 }}>
              Smaller, protein-first meals are often easier on your stomach.
            </Text>
          </View>
        }
        ItemSeparatorComponent={() => <View style={{ height: 1, backgroundColor: C.lineSoft }} />}
        renderItem={({ item }) => {
          const on = !!picked[item.name];
          return (
            <Row style={styles.item}>
              <View style={{ flex: 1 }}>
                <T style={{ fontWeight: '700' }}>{item.name}</T>
                <T variant="small">{item.portion}</T>
              </View>
              <Text style={{ fontWeight: '800', color: C.warmDark }}>{item.protein} g</Text>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={`${on ? 'Remove' : 'Add'} ${item.name}`}
                onPress={() => setPicked({ ...picked, [item.name]: !on })}
                style={[styles.add, on && { backgroundColor: C.accent, borderColor: C.accent }]}>
                <Text style={{ fontWeight: '800', color: on ? C.white : C.accent }}>{on ? '✓' : '+'}</Text>
              </Pressable>
            </Row>
          );
        }}
        ListFooterComponent={
          <View style={{ gap: S.sm, marginTop: S.lg }}>
            <T variant="label" style={{ color: C.inkSoft, fontWeight: '700' }}>
              Something else
            </T>
            <Row style={{ gap: S.sm }}>
              <TextInput
                accessibilityLabel="Food name"
                value={customName}
                onChangeText={setCustomName}
                placeholder="Food"
                placeholderTextColor={C.muted}
                style={[styles.search, { flex: 1, minWidth: 0 }]}
              />
              <TextInput
                accessibilityLabel="Protein in grams"
                value={customG}
                onChangeText={setCustomG}
                keyboardType="number-pad"
                placeholder="g protein"
                placeholderTextColor={C.muted}
                style={[styles.search, { width: 110 }]}
              />
            </Row>
          </View>
        }
      />

      <Row style={styles.footer}>
        <View style={{ flex: 1 }}>
          <T variant="small" style={{ fontWeight: '600' }}>
            {count} items · {meal}
          </T>
          <Text style={{ fontSize: 20, fontWeight: '800', color: C.ink }}>+{total} g protein</Text>
        </View>
        <Button title="Add" onPress={save} disabled={count === 0} style={{ opacity: count === 0 ? 0.5 : 1 }} />
      </Row>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  close: { width: 44, height: 44, borderRadius: 22, backgroundColor: C.card, alignItems: 'center', justifyContent: 'center' },
  search: {
    minHeight: 52,
    borderRadius: R.md,
    borderWidth: 1.5,
    borderColor: C.fieldBorder,
    backgroundColor: C.card,
    paddingHorizontal: S.lg,
    fontSize: 15,
    color: C.ink,
  },
  segment: { flexDirection: 'row', gap: 6, backgroundColor: '#E8EBE5', padding: 4, borderRadius: 14 },
  segItem: { flex: 1, minHeight: 40, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  segOn: { backgroundColor: C.white },
  tip: { backgroundColor: C.warmSoft, borderRadius: R.md, padding: 14, marginBottom: S.md },
  item: { backgroundColor: C.card, minHeight: 64, paddingHorizontal: 14 },
  add: { width: 44, height: 44, borderRadius: 12, borderWidth: 1.5, borderColor: '#CBD3C9', alignItems: 'center', justifyContent: 'center' },
  footer: { backgroundColor: C.card, borderTopWidth: 1, borderTopColor: C.line, padding: S.xl },
});
