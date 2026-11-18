import { Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { C, R, S } from '@/constants/theme';

/** Shown instead of the app when saved data exists but can't be opened. Nothing is written in this state. */
export function StorageProblem({ newer }: { newer: boolean }) {
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg, justifyContent: 'center', padding: S.xl }}>
      <View style={{ backgroundColor: C.card, borderRadius: R.xl, padding: S.xxl, gap: S.md }}>
        <Text style={{ fontSize: 22, fontWeight: '800', color: C.ink }}>
          {newer ? 'Please update Dawnwell' : "We couldn't open your data"}
        </Text>
        <Text style={{ fontSize: 15, lineHeight: 22, color: C.inkSoft }}>
          {newer
            ? 'Your logs were saved by a newer version of the app. Update Dawnwell from the App Store or Google Play to see them.'
            : 'Your logs are still on this phone and nothing was deleted. Close Dawnwell completely and open it again. If this keeps happening, contact support.'}
        </Text>
      </View>
    </SafeAreaView>
  );
}
