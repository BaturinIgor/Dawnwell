import { File, Paths } from 'expo-file-system';
import { router } from 'expo-router';
import * as Sharing from 'expo-sharing';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Platform, Pressable, StyleSheet, Text, View } from 'react-native';

import { Button, Card, Divider, Row, Screen, T } from '@/components/ui';
import { C, R, S } from '@/constants/theme';
import { backupFileName, BackupError, describe, makeBackup, parseBackup } from '@/lib/data/backup';
import { SnapshotInfo } from '@/lib/data/storage-types';
import { useStore } from '@/lib/store';
import { AppData } from '@/lib/types';

const REASON: Record<string, string> = {
  daily: 'Daily copy',
  'before-import': 'Before a file restore',
  'before-restore': 'Before a restore',
};

function when(ms: number): string {
  return new Date(ms).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
}

function confirm(title: string, message: string, action: string): Promise<boolean> {
  if (Platform.OS === 'web') return Promise.resolve(globalThis.confirm?.(`${title}\n\n${message}`) ?? false);
  return new Promise((resolve) =>
    Alert.alert(title, message, [
      { text: 'Cancel', style: 'cancel', onPress: () => resolve(false) },
      { text: action, style: 'destructive', onPress: () => resolve(true) },
    ]),
  );
}

function tell(title: string, message: string) {
  if (Platform.OS === 'web') globalThis.alert?.(`${title}\n\n${message}`);
  else Alert.alert(title, message);
}

export default function DataScreen() {
  const { data, setAside, flush, listSnapshots, restoreSnapshot, replaceWith } = useStore();
  const [snaps, setSnaps] = useState<SnapshotInfo[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const refresh = useCallback(() => {
    listSnapshots()
      .then(setSnaps)
      .catch(() => setSnaps([]));
  }, [listSnapshots]);

  useEffect(refresh, [refresh]);

  const exportFile = async () => {
    setBusy('export');
    try {
      await flush();
      const file = new File(Paths.cache, backupFileName());
      if (file.exists) file.delete();
      file.create();
      await file.write(makeBackup(data));
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(file.uri, { mimeType: 'application/json', dialogTitle: 'Save your Dawnwell backup', UTI: 'public.json' });
      } else {
        tell('Backup ready', `Saved as ${file.name}.`);
      }
    } catch {
      tell("Couldn't make a backup", 'Nothing was changed. Please try again.');
    } finally {
      setBusy(null);
    }
  };

  const importFile = async () => {
    let next: AppData;
    try {
      const picked = await File.pickFileAsync({ mimeTypes: ['application/json', 'text/plain', '*/*'] });
      if (picked.canceled) return;
      next = parseBackup(await picked.result.text()).data;
    } catch (e) {
      tell("Couldn't open the file", e instanceof BackupError ? e.message : 'Please try again.');
      return;
    }
    const ok = await confirm(
      'Restore this backup?',
      `It has ${describe(next)}. It will replace what is on this phone now (${describe(data)}). A copy of your current data is kept, so you can undo this below.`,
      'Restore',
    );
    if (!ok) return;
    setBusy('import');
    try {
      await replaceWith(next);
      refresh();
      tell('Restored', 'Your backup is back in place.');
    } catch {
      tell("Couldn't restore", 'Nothing was changed. Please try again.');
    } finally {
      setBusy(null);
    }
  };

  const restore = async (s: SnapshotInfo) => {
    const ok = await confirm(
      'Go back to this copy?',
      `Copy from ${when(s.takenAt)} with ${s.dayCount} day${s.dayCount === 1 ? '' : 's'} of logs. Your current data is kept as a copy first.`,
      'Go back',
    );
    if (!ok) return;
    setBusy(`snap-${s.id}`);
    try {
      await restoreSnapshot(s.id);
      refresh();
    } catch {
      tell("Couldn't restore", 'Nothing was changed. Please try again.');
    } finally {
      setBusy(null);
    }
  };

  return (
    <Screen>
      <Row style={{ justifyContent: 'space-between' }}>
        <Pressable accessibilityRole="button" accessibilityLabel="Back" onPress={() => router.back()} style={styles.back}>
          <Text style={{ fontSize: 20, color: C.ink }}>‹</Text>
        </Pressable>
        <T variant="h2">Your data</T>
        <View style={{ width: 44 }} />
      </Row>

      <View style={styles.hero}>
        <Text style={styles.heroTitle}>Saved on this phone</Text>
        <Text style={styles.heroBody}>
          {describe(data)}. Dawnwell keeps your logs on your device and never sends them to us.
        </Text>
      </View>

      {setAside > 0 ? (
        <Card style={{ backgroundColor: C.warmSoft }}>
          <Text style={{ color: C.warmInk, fontSize: 14, lineHeight: 20 }}>
            {setAside} saved record{setAside === 1 ? '' : 's'} couldn&apos;t be read and {setAside === 1 ? 'was' : 'were'} set aside, not deleted. If
            something looks missing, go back to one of the copies below.
          </Text>
        </Card>
      ) : null}

      <Card>
        <T variant="h2">Backup file</T>
        <T variant="small">
          Save a file to Files, iCloud Drive, Google Drive or email. Use it to move to a new phone, including from iPhone to Android.
        </T>
        <Button title={busy === 'export' ? 'Preparing…' : 'Save a backup file'} onPress={exportFile} disabled={!!busy} />
        <Button title={busy === 'import' ? 'Restoring…' : 'Restore from a file'} kind="secondary" onPress={importFile} disabled={!!busy} />
      </Card>

      <View style={{ gap: S.sm }}>
        <T variant="label" style={{ color: C.inkSoft, fontWeight: '700' }}>
          Copies on this phone
        </T>
        <Card style={{ gap: S.sm }}>
          <T variant="small">One copy a day for the last week, plus a copy before every restore.</T>
          {snaps === null ? (
            <ActivityIndicator color={C.accent} />
          ) : snaps.length === 0 ? (
            <T variant="small">The first copy is made tomorrow.</T>
          ) : (
            snaps.map((s, i) => (
              <View key={s.id} style={{ gap: S.sm }}>
                {i > 0 ? <Divider /> : null}
                <Row style={{ justifyContent: 'space-between' }}>
                  <View style={{ flex: 1 }}>
                    <T style={{ fontWeight: '700' }}>{when(s.takenAt)}</T>
                    <T variant="small">
                      {REASON[s.reason] ?? 'Copy'} · {s.dayCount} day{s.dayCount === 1 ? '' : 's'}
                    </T>
                  </View>
                  <Pressable
                    accessibilityRole="button"
                    accessibilityLabel={`Go back to copy from ${when(s.takenAt)}`}
                    disabled={!!busy}
                    onPress={() => restore(s)}
                    style={styles.restore}>
                    <Text style={{ color: C.accent, fontWeight: '800' }}>{busy === `snap-${s.id}` ? '…' : 'Go back'}</Text>
                  </Pressable>
                </Row>
              </View>
            ))
          )}
        </Card>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  back: { width: 44, height: 44, borderRadius: 22, backgroundColor: C.card, alignItems: 'center', justifyContent: 'center' },
  hero: { backgroundColor: C.accentSoft, borderRadius: R.xl, padding: S.xxl, gap: 6 },
  heroTitle: { color: C.accentDark, fontSize: 20, fontWeight: '800' },
  heroBody: { color: C.inkSoft, fontSize: 15, lineHeight: 22 },
  restore: { minHeight: 44, paddingHorizontal: S.md, borderRadius: R.sm, borderWidth: 1.5, borderColor: C.fieldBorder, justifyContent: 'center' },
});
