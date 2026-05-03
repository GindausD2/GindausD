import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';

interface OrbProps {
  /** 'idle' | 'listening' | 'thinking' | 'speaking' */
  state: 'idle' | 'listening' | 'thinking' | 'speaking';
  size?: number;
}

export function Orb({ state, size = 140 }: OrbProps) {
  const pulse = useRef(new Animated.Value(1)).current;
  const glow = useRef(new Animated.Value(0)).current;
  const rotate = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    let pulseAnim: Animated.CompositeAnimation;
    let glowAnim: Animated.CompositeAnimation;
    let rotateAnim: Animated.CompositeAnimation;

    if (state === 'idle') {
      pulseAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(pulse, { toValue: 1.04, duration: 2200, useNativeDriver: true }),
          Animated.timing(pulse, { toValue: 1, duration: 2200, useNativeDriver: true }),
        ])
      );
      glowAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(glow, { toValue: 0.3, duration: 2200, useNativeDriver: true }),
          Animated.timing(glow, { toValue: 0, duration: 2200, useNativeDriver: true }),
        ])
      );
      rotateAnim = Animated.loop(
        Animated.timing(rotate, { toValue: 1, duration: 12000, useNativeDriver: true })
      );
    } else if (state === 'listening') {
      pulseAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(pulse, { toValue: 1.12, duration: 500, useNativeDriver: true }),
          Animated.timing(pulse, { toValue: 0.96, duration: 500, useNativeDriver: true }),
        ])
      );
      glowAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(glow, { toValue: 0.8, duration: 500, useNativeDriver: true }),
          Animated.timing(glow, { toValue: 0.4, duration: 500, useNativeDriver: true }),
        ])
      );
      rotateAnim = Animated.loop(
        Animated.timing(rotate, { toValue: 1, duration: 4000, useNativeDriver: true })
      );
    } else if (state === 'thinking') {
      pulseAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(pulse, { toValue: 1.06, duration: 800, useNativeDriver: true }),
          Animated.timing(pulse, { toValue: 0.98, duration: 800, useNativeDriver: true }),
        ])
      );
      glowAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(glow, { toValue: 0.6, duration: 800, useNativeDriver: true }),
          Animated.timing(glow, { toValue: 0.2, duration: 800, useNativeDriver: true }),
        ])
      );
      rotateAnim = Animated.loop(
        Animated.timing(rotate, { toValue: 1, duration: 3000, useNativeDriver: true })
      );
    } else {
      // speaking
      pulseAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(pulse, { toValue: 1.15, duration: 350, useNativeDriver: true }),
          Animated.timing(pulse, { toValue: 0.95, duration: 350, useNativeDriver: true }),
        ])
      );
      glowAnim = Animated.loop(
        Animated.sequence([
          Animated.timing(glow, { toValue: 1, duration: 350, useNativeDriver: true }),
          Animated.timing(glow, { toValue: 0.5, duration: 350, useNativeDriver: true }),
        ])
      );
      rotateAnim = Animated.loop(
        Animated.timing(rotate, { toValue: 1, duration: 2000, useNativeDriver: true })
      );
    }

    pulseAnim.start();
    glowAnim.start();
    rotateAnim.start();

    return () => {
      pulseAnim.stop();
      glowAnim.stop();
      rotateAnim.stop();
    };
  }, [state]);

  const spin = rotate.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  // Orb gradient colors by state
  const gradientColors: Record<string, readonly [string, string, string]> = {
    idle: ['#C9A97A', '#8B5E3C', '#3B1F0A'],
    listening: ['#7C3AED', '#4F46E5', '#1E1B4B'],
    thinking: ['#6B7280', '#374151', '#111827'],
    speaking: ['#7C3AED', '#9D5FFF', '#4F46E5'],
  };

  const colors = gradientColors[state] ?? gradientColors.idle;

  return (
    <View style={[styles.wrapper, { width: size * 1.5, height: size * 1.5 }]}>
      {/* Outer glow ring */}
      <Animated.View
        style={[
          styles.glowRing,
          {
            width: size * 1.4,
            height: size * 1.4,
            borderRadius: size * 0.7,
            opacity: glow,
            transform: [{ scale: pulse }],
            backgroundColor: state === 'listening' ? 'rgba(124,58,237,0.15)' : 'rgba(201,169,122,0.15)',
          },
        ]}
      />

      {/* Main orb */}
      <Animated.View
        style={[
          styles.orbOuter,
          {
            width: size,
            height: size,
            borderRadius: size / 2,
            transform: [{ scale: pulse }],
          },
        ]}
      >
        {/* Rotating gradient inner */}
        <Animated.View
          style={[
            StyleSheet.absoluteFill,
            {
              borderRadius: size / 2,
              overflow: 'hidden',
              transform: [{ rotate: spin }],
            },
          ]}
        >
          <LinearGradient
            colors={colors}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={StyleSheet.absoluteFill}
          />
        </Animated.View>

        {/* Highlight */}
        <View style={[styles.highlight, { width: size * 0.35, height: size * 0.2, borderRadius: size * 0.1 }]} />
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  glowRing: {
    position: 'absolute',
  },
  orbOuter: {
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'flex-start',
    paddingTop: 14,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 20,
    elevation: 12,
  },
  highlight: {
    backgroundColor: 'rgba(255,255,255,0.25)',
  },
});
