import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Card, Row, Screen, T } from '@/components/ui';
import { C, R, S } from '@/constants/theme';
import { parseDay } from '@/lib/date';
import { useStore } from '@/lib/store';
import { useNow } from '@/hooks/use-now';

const STAGES = [
  {
    upTo: 14,
    title: 'Your first two weeks',
    tip: 'Mild nausea is common at the start. Eat slowly, stop when you feel full, and go easy on fatty food.',
  },
  {
    upTo: 60,
    title: 'Settling in',
    tip: 'Your appetite may be smaller now. Put protein first on your plate so you still reach your target.',
  },
  {
    upTo: Infinity,
    title: 'Keeping it going',
    tip: 'Strength work two or three times a week helps you keep muscle. Keep logging so your visits stay easy.',
  },
];

const ARTICLES = [
  {
    title: 'Why the empty-stomach wait matters',
    minutes: 2,
    body: 'Oral GLP-1 tablets are absorbed best when your stomach is empty. Take the tablet with only the amount of water your label says, then wait the time on your label before food, drinks or other medicines. Eating too soon can mean less of the medicine gets absorbed. If you are unsure about your wait time, ask your pharmacist.',
  },
  {
    title: 'Protein: how much and from what',
    minutes: 3,
    body: 'When you eat less, protein helps protect muscle. Many people aim for a portion of protein at every meal: Greek yogurt, eggs, cottage cheese, fish, chicken, tofu or a protein shake. Your care team can help you set a daily target that fits you.',
  },
  {
    title: 'Easing nausea',
    minutes: 2,
    body: 'Smaller meals, eating slowly and stopping at the first sign of fullness all help. Fatty, fried and very sweet food is often harder. Sip water through the day. If nausea is severe, you keep vomiting, or you have strong stomach pain, contact your clinician.',
  },
  {
    title: 'Constipation and fiber',
    minutes: 2,
    body: 'Less food often means less fiber and fluid. Add vegetables, berries, oats, beans or a fiber supplement, and drink water through the day. Tell your clinician if it lasts more than a few days.',
  },
  {
    title: 'If you miss a tablet',
    minutes: 1,
    body: 'Follow the instructions on your medication guide or ask your pharmacist. Do not take two tablets to make up for a missed one. Log a skipped day in the app so your visit summary stays accurate.',
  },
  {
    title: 'Getting ready for your visit',
    minutes: 2,
    body: 'Open the Report tab a day before. Add the questions you want to ask, then share the summary with yourself or your care team. Bring up any symptom that lasted more than a few days.',
  },
];

export default function Learn() {
  const { data } = useStore();
  const [open, setOpen] = useState<string | null>(null);
  const now = useNow();

  const startKey = data.doseHistory[0]?.from ?? Object.keys(data.days).sort()[0];
  const day = startKey ? Math.max(1, Math.floor((now - parseDay(startKey).getTime()) / 86_400_000) + 1) : 1;
  const stage = STAGES.find((x) => day <= x.upTo) ?? STAGES[STAGES.length - 1];

  return (
    <Screen>
      <T variant="title">Learn</T>

      <View style={styles.stage}>
        <Text style={styles.stageLabel}>Day {day}</Text>
        <Text style={styles.stageTitle}>{stage.title}</Text>
        <Text style={styles.stageTip}>{stage.tip}</Text>
      </View>

      <View style={{ gap: S.sm }}>
        {ARTICLES.map((a) => {
          const on = open === a.title;
          return (
            <Pressable
              key={a.title}
              accessibilityRole="button"
              accessibilityState={{ expanded: on }}
              onPress={() => setOpen(on ? null : a.title)}>
              <Card style={{ gap: S.sm, padding: S.lg }}>
                <Row style={{ justifyContent: 'space-between' }}>
                  <View style={{ flex: 1 }}>
                    <T style={{ fontWeight: '700' }}>{a.title}</T>
                    <T variant="small">{a.minutes} min read</T>
                  </View>
                  <Text style={{ fontSize: 18, color: C.muted }}>{on ? '−' : '+'}</Text>
                </Row>
                {on ? <T style={{ color: C.inkSoft }}>{a.body}</T> : null}
              </Card>
            </Pressable>
          );
        })}
      </View>

      <T variant="small" style={{ textAlign: 'center' }}>
        General information, not medical advice. Your medication guide and your care team come first.
      </T>
    </Screen>
  );
}

const styles = StyleSheet.create({
  stage: { backgroundColor: C.sand, borderRadius: R.xl, padding: S.xxl, gap: 6 },
  stageLabel: { color: C.sandInk, fontSize: 13, fontWeight: '800' },
  stageTitle: { color: C.ink, fontSize: 22, fontWeight: '800', letterSpacing: -0.3 },
  stageTip: { color: C.inkSoft, fontSize: 15, lineHeight: 22 },
});
