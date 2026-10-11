import React, { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Animated, StyleSheet, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
interface OrbProps { state: 'idle' | 'listening' | 'thinking' | 'speaking'; size?: number }
export function Orb({ state, size = 96 }: OrbProps) {
  const pulse = useRef(new Animated.Value(1)).current;
  const [reducedMotion, setReducedMotion] = useState(true);
  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then(setReducedMotion);
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setReducedMotion);
    return () => sub.remove();
  }, []);
  useEffect(() => {
    pulse.setValue(1);
    if (state === 'idle' || reducedMotion) return;
    const animation = Animated.loop(Animated.sequence([
      Animated.timing(pulse, { toValue: 1.035, duration: 900, useNativeDriver: true }),
      Animated.timing(pulse, { toValue: 1, duration: 900, useNativeDriver: true }),
    ]));
    animation.start();
    return () => animation.stop();
  }, [state, reducedMotion, pulse]);
  return (
    <Animated.View accessible={false} style={[styles.pearl, { width: size, height: size, borderRadius: size / 2, transform: [{ scale: pulse }] }]}>
      <LinearGradient colors={['#FFFFFF', '#E8ECE5', '#A9B5A7']} start={{ x: 0.22, y: 0 }} end={{ x: 0.8, y: 1 }} style={StyleSheet.absoluteFill} />
      <View style={styles.wave}>
        {[0.28, 0.48, 0.72, 0.48, 0.28].map((height, i) => <View key={i} style={{ width: 3, height: size * height * 0.45, borderRadius: 3, backgroundColor: '#5E6A5C' }} />)}
      </View>
    </Animated.View>
  );
}
const styles = StyleSheet.create({
  pearl: { overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.9)', justifyContent: 'center', alignItems: 'center' },
  wave: { flexDirection: 'row', gap: 4, alignItems: 'center' },
});
