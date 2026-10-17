import React, { useEffect, useState } from 'react';
import { AccessibilityInfo, Platform, StyleSheet, View, ViewStyle, StyleProp } from 'react-native';
import { BlurView } from 'expo-blur';

export function GlassSurface({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  const [opaque, setOpaque] = useState(false);
  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    AccessibilityInfo.isReduceTransparencyEnabled().then(setOpaque);
    const subscription = AccessibilityInfo.addEventListener('reduceTransparencyChanged', setOpaque);
    return () => subscription.remove();
  }, []);
  return (
    <View style={[styles.shell, style]}>
      {Platform.OS === 'ios' && !opaque ? <BlurView intensity={45} tint="light" style={StyleSheet.absoluteFill} /> : null}
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: opaque ? '#FFFFFF' : 'rgba(255,255,255,0.68)' }]} />
      {children}
    </View>
  );
}
const styles = StyleSheet.create({ shell: { overflow: 'hidden', borderRadius: 28, borderWidth: 1, borderColor: 'rgba(255,255,255,0.95)' } });
