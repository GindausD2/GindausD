import React, { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Animated, StyleSheet, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';

interface OrbProps { state: 'idle' | 'listening' | 'thinking' | 'speaking'; size?: number }
const heights = [0.24, 0.43, 0.64, 0.43, 0.24];

export function Orb({ state, size = 96 }: OrbProps) {
  const pulse = useRef(new Animated.Value(0)).current;
  const bars = useRef(heights.map(() => new Animated.Value(1))).current;
  const [reducedMotion, setReducedMotion] = useState(true);
  useEffect(() => {
    let active = true;
    AccessibilityInfo.isReduceMotionEnabled().then(value => { if (active) setReducedMotion(value); });
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setReducedMotion);
    return () => { active = false; sub.remove(); };
  }, []);
  useEffect(() => {
    pulse.setValue(0);
    bars.forEach(bar => bar.setValue(1));
    if (state === 'idle' || reducedMotion) return;
    const duration = state === 'speaking' ? 620 : 1100;
    const breathing = Animated.loop(Animated.sequence([
      Animated.timing(pulse, { toValue: 1, duration, useNativeDriver: true }),
      Animated.timing(pulse, { toValue: 0, duration, useNativeDriver: true }),
    ]));
    const waves = bars.map((bar, index) => Animated.loop(Animated.sequence([
      Animated.timing(bar, { toValue: 0.5 + index * 0.08, duration: 220 + index * 60, useNativeDriver: true }),
      Animated.timing(bar, { toValue: 1.2 - index * 0.04, duration: 330 + index * 50, useNativeDriver: true }),
      Animated.timing(bar, { toValue: 1, duration: 270, useNativeDriver: true }),
    ])));
    breathing.start();
    if (state === 'speaking' || state === 'listening') waves.forEach(wave => wave.start());
    return () => { breathing.stop(); waves.forEach(wave => wave.stop()); };
  }, [state, reducedMotion, pulse, bars]);
  const diameter = size * 1.42;
  return (
    <View accessible={false} style={{ width: diameter, height: diameter, alignItems: 'center', justifyContent: 'center' }}>
      <Animated.View style={[styles.halo, { width: diameter, height: diameter, borderRadius: diameter / 2, opacity: pulse.interpolate({ inputRange: [0, 1], outputRange: [0.45, 0.85] }), transform: [{ scale: pulse.interpolate({ inputRange: [0, 1], outputRange: [0.94, 1.04] }) }] }]} />
      <View style={[styles.glassRing, { width: size * 1.21, height: size * 1.21, borderRadius: size }]} />
      <Animated.View style={[styles.pearl, { width: size, height: size, borderRadius: size / 2, transform: [{ scale: pulse.interpolate({ inputRange: [0, 1], outputRange: [1, state === 'speaking' ? 1.035 : 1.018] }) }] }]}>
        <LinearGradient colors={['#F0FBFF', '#BDE5F4', '#79B9D4', '#538FAA']} locations={[0, 0.4, 0.76, 1]} start={{ x: 0.2, y: 0 }} end={{ x: 0.78, y: 1 }} style={StyleSheet.absoluteFill} />
        <View style={[styles.reflection, { width: size * 0.66, height: size * 0.3, top: size * 0.08, left: size * 0.13, borderRadius: size }]}>
          <LinearGradient colors={['rgba(255,255,255,0.85)', 'rgba(255,255,255,0)']} style={StyleSheet.absoluteFill} />
        </View>
        <View style={styles.wave}>
          {heights.map((height, i) => <Animated.View key={i} style={{ width: Math.max(3, size * 0.027), height: size * height * 0.5, borderRadius: 4, backgroundColor: '#315E73', transform: [{ scaleY: bars[i] }] }} />)}
        </View>
      </Animated.View>
    </View>
  );
}
const styles = StyleSheet.create({
  halo: { position: 'absolute', borderWidth: 1, borderColor: '#FFFFFF', backgroundColor: 'rgba(194,231,244,0.2)' },
  glassRing: { position: 'absolute', borderWidth: 1, borderColor: 'rgba(255,255,255,0.8)', backgroundColor: 'rgba(255,255,255,0.2)' },
  pearl: { overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.95)', justifyContent: 'center', alignItems: 'center', shadowColor: '#467B94', shadowOpacity: 0.2, shadowRadius: 20, shadowOffset: { width: 0, height: 10 } },
  reflection: { position: 'absolute', overflow: 'hidden', transform: [{ rotate: '-22deg' }] },
  wave: { flexDirection: 'row', gap: 4, alignItems: 'center' },
});
