import React, { useRef, useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  Pressable,
  ScrollView,
  StyleSheet,
  Dimensions,
  Alert,
  ActivityIndicator,
  Platform,
  Animated,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Orb } from '@/components/Orb';
import { signIn, signUp, startDemo } from '@/services/auth';

const { width: W, height: H } = Dimensions.get('window');

const PAGE_LOGIN = 0;
const PAGE_WELCOME = 1;
const PAGE_SIGNUP = 2;

// ─── Glass card wrapper ───────────────────────────────────────────────────────

function GlassCard({ children, style }: { children: React.ReactNode; style?: object }) {
  if (Platform.OS === 'ios') {
    return (
      <BlurView intensity={28} tint="light" style={[styles.glassCard, style]}>
        <View style={styles.glassInner}>{children}</View>
      </BlurView>
    );
  }
  // Android fallback — translucent white
  return (
    <View style={[styles.glassCard, styles.glassCardAndroid, style]}>
      {children}
    </View>
  );
}

// ─── Glass input field ────────────────────────────────────────────────────────

function GlassField({
  icon,
  placeholder,
  value,
  onChangeText,
  secureTextEntry,
  keyboardType,
  autoCapitalize,
  rightElement,
  autoCorrect,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  placeholder: string;
  value: string;
  onChangeText: (t: string) => void;
  secureTextEntry?: boolean;
  keyboardType?: 'default' | 'email-address';
  autoCapitalize?: 'none' | 'words' | 'sentences';
  rightElement?: React.ReactNode;
  autoCorrect?: boolean;
}) {
  return (
    <View style={styles.fieldWrap}>
      <Ionicons name={icon} size={18} color="rgba(255,255,255,0.7)" style={styles.fieldIcon} />
      <TextInput
        style={[styles.fieldInput, rightElement ? { flex: 1 } : null]}
        placeholder={placeholder}
        placeholderTextColor="rgba(255,255,255,0.45)"
        value={value}
        onChangeText={onChangeText}
        secureTextEntry={secureTextEntry}
        keyboardType={keyboardType ?? 'default'}
        autoCapitalize={autoCapitalize ?? 'none'}
        autoCorrect={autoCorrect ?? false}
        selectionColor="rgba(255,255,255,0.8)"
      />
      {rightElement}
    </View>
  );
}

// ─── Main welcome screen ──────────────────────────────────────────────────────

export default function WelcomeScreen() {
  const scrollRef = useRef<ScrollView>(null);
  const [currentPage, setCurrentPage] = useState(PAGE_WELCOME);
  const [isLoading, setIsLoading] = useState(false);

  // Login form
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [showLoginPass, setShowLoginPass] = useState(false);

  // Signup form
  const [signupName, setSignupName] = useState('');
  const [signupEmail, setSignupEmail] = useState('');
  const [signupPassword, setSignupPassword] = useState('');
  const [showSignupPass, setShowSignupPass] = useState(false);

  // Subtle shimmer animation for the glass highlight
  const shimmer = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Start at center page
    scrollRef.current?.scrollTo({ x: W, animated: false });

    // Looping shimmer on the glass cards
    Animated.loop(
      Animated.sequence([
        Animated.timing(shimmer, { toValue: 1, duration: 2800, useNativeDriver: true }),
        Animated.timing(shimmer, { toValue: 0, duration: 2800, useNativeDriver: true }),
      ])
    ).start();
  }, []);

  const handleScroll = useCallback((e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const page = Math.round(e.nativeEvent.contentOffset.x / W);
    setCurrentPage(page);
  }, []);

  const goToPage = (page: number) => {
    scrollRef.current?.scrollTo({ x: page * W, animated: true });
  };

  const handleLogin = async () => {
    if (!loginEmail.trim() || !loginPassword.trim()) {
      Alert.alert('Missing fields', 'Please enter your email and password.');
      return;
    }
    setIsLoading(true);
    try {
      await signIn(loginEmail.trim(), loginPassword);
      router.replace('/');
    } catch {
      Alert.alert('Error', 'Login failed. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSignUp = async () => {
    if (!signupName.trim() || !signupEmail.trim() || !signupPassword.trim()) {
      Alert.alert('Missing fields', 'Please fill in all fields.');
      return;
    }
    if (signupPassword.length < 6) {
      Alert.alert('Weak password', 'Password must be at least 6 characters.');
      return;
    }
    setIsLoading(true);
    try {
      await signUp(signupName.trim(), signupEmail.trim(), signupPassword);
      router.replace('/');
    } catch {
      Alert.alert('Error', 'Sign up failed. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDemo = async () => {
    setIsLoading(true);
    try {
      await startDemo();
    } finally {
      router.replace('/');
    }
  };

  const shimmerOpacity = shimmer.interpolate({ inputRange: [0, 1], outputRange: [0.06, 0.18] });

  return (
    <View style={styles.root}>
      {/* ── Background gradient ─────────────────────────────────────────── */}
      <LinearGradient
        colors={['#2D1B69', '#4F46E5', '#7C3AED', '#C084FC']}
        start={{ x: 0.1, y: 0 }}
        end={{ x: 0.9, y: 1 }}
        style={StyleSheet.absoluteFill}
      />

      {/* Animated shimmer overlay */}
      <Animated.View
        pointerEvents="none"
        style={[StyleSheet.absoluteFill, { opacity: shimmerOpacity, backgroundColor: '#fff' }]}
      />

      {/* Decorative blobs */}
      <View style={[styles.blob, styles.blob1]} />
      <View style={[styles.blob, styles.blob2]} />

      <SafeAreaView style={{ flex: 1 }} edges={['top', 'bottom']}>

        {/* ── Page indicator dots ──────────────────────────────────────── */}
        <View style={styles.dotsRow}>
          {[PAGE_LOGIN, PAGE_WELCOME, PAGE_SIGNUP].map((p) => (
            <Animated.View
              key={p}
              style={[styles.dot, currentPage === p && styles.dotActive]}
            />
          ))}
        </View>

        {/* ── Horizontal pager ─────────────────────────────────────────── */}
        <ScrollView
          ref={scrollRef}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          onMomentumScrollEnd={handleScroll}
          scrollEventThrottle={16}
          bounces={false}
          keyboardShouldPersistTaps="handled"
          style={{ flex: 1 }}
        >

          {/* ═══ PAGE 0: Login ═══════════════════════════════════════════ */}
          <View style={styles.page}>
            <Pressable onPress={() => goToPage(PAGE_WELCOME)} hitSlop={12} style={styles.backRow}>
              <Ionicons name="chevron-back" size={20} color="rgba(255,255,255,0.8)" />
              <Text style={styles.backLabel}>Back</Text>
            </Pressable>

            <Text style={styles.formTitle}>Welcome back</Text>
            <Text style={styles.formSubtitle}>Sign in to continue with Max</Text>

            <GlassCard style={styles.formCard}>
              <GlassField
                icon="mail-outline"
                placeholder="Email address"
                value={loginEmail}
                onChangeText={setLoginEmail}
                keyboardType="email-address"
              />
              <View style={styles.fieldSep} />
              <GlassField
                icon="lock-closed-outline"
                placeholder="Password"
                value={loginPassword}
                onChangeText={setLoginPassword}
                secureTextEntry={!showLoginPass}
                rightElement={
                  <Pressable onPress={() => setShowLoginPass(v => !v)} hitSlop={8}>
                    <Ionicons
                      name={showLoginPass ? 'eye-off-outline' : 'eye-outline'}
                      size={18}
                      color="rgba(255,255,255,0.6)"
                    />
                  </Pressable>
                }
              />
            </GlassCard>

            <Pressable
              style={[styles.primaryBtn, isLoading && styles.btnDisabled]}
              onPress={handleLogin}
              disabled={isLoading}
            >
              {isLoading
                ? <ActivityIndicator color="#fff" />
                : <Text style={styles.primaryBtnText}>Login</Text>}
            </Pressable>

            <Pressable onPress={() => goToPage(PAGE_SIGNUP)} style={styles.linkRow}>
              <Text style={styles.linkText}>
                New here? <Text style={styles.linkBold}>Sign up →</Text>
              </Text>
            </Pressable>
          </View>

          {/* ═══ PAGE 1: Welcome (center) ════════════════════════════════ */}
          <View style={[styles.page, styles.welcomePage]}>
            {/* Orb */}
            <View style={styles.orbContainer}>
              <Orb state="idle" size={96} />
            </View>

            {/* Logo glass card */}
            <GlassCard style={styles.logoCard}>
              {/* Specular highlight line */}
              <View style={styles.specular} />
              <Text style={styles.appName}>Max</Text>
              <Text style={styles.appTagline}>
                Your AI companion,{'\n'}always in your pocket.
              </Text>
            </GlassCard>

            {/* Swipe action row */}
            <View style={styles.swipeRow}>
              <Pressable style={styles.swipeBtn} onPress={() => goToPage(PAGE_LOGIN)}>
                <GlassCard style={styles.swipePill}>
                  <Ionicons name="chevron-back" size={16} color="#fff" />
                  <Text style={styles.swipePillText}>Login</Text>
                </GlassCard>
              </Pressable>

              <Pressable style={styles.swipeBtn} onPress={() => goToPage(PAGE_SIGNUP)}>
                <GlassCard style={styles.swipePill}>
                  <Text style={styles.swipePillText}>Get started</Text>
                  <Ionicons name="chevron-forward" size={16} color="#fff" />
                </GlassCard>
              </Pressable>
            </View>

            {/* Divider */}
            <View style={styles.dividerRow}>
              <View style={styles.dividerLine} />
              <Text style={styles.dividerText}>or</Text>
              <View style={styles.dividerLine} />
            </View>

            {/* Try Demo */}
            <Pressable
              style={styles.demoBtn}
              onPress={handleDemo}
              disabled={isLoading}
            >
              {isLoading ? (
                <ActivityIndicator color="rgba(255,255,255,0.9)" />
              ) : (
                <>
                  <Ionicons name="flash" size={18} color="rgba(255,255,255,0.95)" />
                  <Text style={styles.demoBtnText}>Try Demo</Text>
                </>
              )}
            </Pressable>
          </View>

          {/* ═══ PAGE 2: Sign up ═════════════════════════════════════════ */}
          <View style={styles.page}>
            <Pressable onPress={() => goToPage(PAGE_WELCOME)} hitSlop={12} style={styles.backRow}>
              <Ionicons name="chevron-back" size={20} color="rgba(255,255,255,0.8)" />
              <Text style={styles.backLabel}>Back</Text>
            </Pressable>

            <Text style={styles.formTitle}>Create account</Text>
            <Text style={styles.formSubtitle}>Start your Max journey today</Text>

            <GlassCard style={styles.formCard}>
              <GlassField
                icon="person-outline"
                placeholder="Your name"
                value={signupName}
                onChangeText={setSignupName}
                autoCapitalize="words"
                autoCorrect={false}
              />
              <View style={styles.fieldSep} />
              <GlassField
                icon="mail-outline"
                placeholder="Email address"
                value={signupEmail}
                onChangeText={setSignupEmail}
                keyboardType="email-address"
              />
              <View style={styles.fieldSep} />
              <GlassField
                icon="lock-closed-outline"
                placeholder="Password (min 6 chars)"
                value={signupPassword}
                onChangeText={setSignupPassword}
                secureTextEntry={!showSignupPass}
                rightElement={
                  <Pressable onPress={() => setShowSignupPass(v => !v)} hitSlop={8}>
                    <Ionicons
                      name={showSignupPass ? 'eye-off-outline' : 'eye-outline'}
                      size={18}
                      color="rgba(255,255,255,0.6)"
                    />
                  </Pressable>
                }
              />
            </GlassCard>

            <Pressable
              style={[styles.primaryBtn, isLoading && styles.btnDisabled]}
              onPress={handleSignUp}
              disabled={isLoading}
            >
              {isLoading
                ? <ActivityIndicator color="#fff" />
                : <Text style={styles.primaryBtnText}>Get Started</Text>}
            </Pressable>

            <Pressable onPress={() => goToPage(PAGE_LOGIN)} style={styles.linkRow}>
              <Text style={styles.linkText}>
                Already have an account? <Text style={styles.linkBold}>← Login</Text>
              </Text>
            </Pressable>
          </View>

        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#1E1B4B',
  },

  // ── Decorative blobs ────────────────────────────────────────────────────────
  blob: {
    position: 'absolute',
    borderRadius: 999,
    opacity: 0.25,
  },
  blob1: {
    width: 280,
    height: 280,
    backgroundColor: '#C084FC',
    top: -60,
    right: -80,
  },
  blob2: {
    width: 220,
    height: 220,
    backgroundColor: '#818CF8',
    bottom: 60,
    left: -60,
  },

  // ── Page dots ───────────────────────────────────────────────────────────────
  dotsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 7,
    paddingTop: 12,
    paddingBottom: 6,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: 'rgba(255,255,255,0.3)',
  },
  dotActive: {
    width: 20,
    backgroundColor: '#fff',
    borderRadius: 3,
  },

  // ── Page layout ─────────────────────────────────────────────────────────────
  page: {
    width: W,
    flex: 1,
    paddingHorizontal: 28,
    paddingTop: 8,
    paddingBottom: 16,
    justifyContent: 'center',
  },
  welcomePage: {
    alignItems: 'center',
  },

  // ── Back button ─────────────────────────────────────────────────────────────
  backRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 28,
    alignSelf: 'flex-start',
  },
  backLabel: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 15,
    fontWeight: '500',
  },

  // ── Form titles ─────────────────────────────────────────────────────────────
  formTitle: {
    fontSize: 30,
    fontWeight: '700',
    color: '#fff',
    marginBottom: 6,
  },
  formSubtitle: {
    fontSize: 15,
    color: 'rgba(255,255,255,0.65)',
    marginBottom: 28,
  },

  // ── Glass card ──────────────────────────────────────────────────────────────
  glassCard: {
    borderRadius: 22,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.25)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.25,
    shadowRadius: 32,
    elevation: 12,
  },
  glassCardAndroid: {
    backgroundColor: 'rgba(255,255,255,0.18)',
  },
  glassInner: {
    // Ensures content renders on top of the blur
  },

  // ── Form card ───────────────────────────────────────────────────────────────
  formCard: {
    marginBottom: 16,
  },

  // ── Input field ─────────────────────────────────────────────────────────────
  fieldWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 15,
    gap: 12,
  },
  fieldIcon: {
    width: 20,
    textAlign: 'center',
  },
  fieldInput: {
    flex: 1,
    fontSize: 15,
    color: '#fff',
    fontWeight: '400',
  },
  fieldSep: {
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.12)',
    marginHorizontal: 16,
  },

  // ── Primary button ──────────────────────────────────────────────────────────
  primaryBtn: {
    height: 54,
    borderRadius: 16,
    backgroundColor: 'rgba(255,255,255,0.22)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.35)',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 6,
  },
  btnDisabled: {
    opacity: 0.5,
  },
  primaryBtnText: {
    fontSize: 17,
    fontWeight: '700',
    color: '#fff',
    letterSpacing: 0.3,
  },

  // ── Link row ────────────────────────────────────────────────────────────────
  linkRow: {
    alignItems: 'center',
    paddingVertical: 4,
  },
  linkText: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.6)',
  },
  linkBold: {
    fontWeight: '700',
    color: 'rgba(255,255,255,0.95)',
  },

  // ── Welcome page ────────────────────────────────────────────────────────────
  orbContainer: {
    marginBottom: 24,
  },
  logoCard: {
    width: W - 64,
    alignItems: 'center',
    paddingVertical: 28,
    paddingHorizontal: 24,
    marginBottom: 28,
  },
  specular: {
    position: 'absolute',
    top: 0,
    left: 20,
    right: 20,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.55)',
    borderRadius: 1,
  },
  appName: {
    fontSize: 40,
    fontWeight: '800',
    color: '#fff',
    letterSpacing: 3,
    marginBottom: 10,
  },
  appTagline: {
    fontSize: 15,
    color: 'rgba(255,255,255,0.75)',
    textAlign: 'center',
    lineHeight: 22,
  },

  // ── Swipe action pills ──────────────────────────────────────────────────────
  swipeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: W - 64,
    marginBottom: 20,
    gap: 12,
  },
  swipeBtn: {
    flex: 1,
  },
  swipePill: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 12,
    paddingHorizontal: 14,
  },
  swipePillText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },

  // ── Divider ─────────────────────────────────────────────────────────────────
  dividerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    width: W - 64,
    marginBottom: 20,
    gap: 12,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  dividerText: {
    color: 'rgba(255,255,255,0.5)',
    fontSize: 13,
    fontWeight: '500',
  },

  // ── Try Demo button ──────────────────────────────────────────────────────────
  demoBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    width: W - 64,
    height: 50,
    borderRadius: 14,
    borderWidth: 1.5,
    borderColor: 'rgba(255,255,255,0.3)',
    backgroundColor: 'rgba(255,255,255,0.1)',
  },
  demoBtnText: {
    fontSize: 16,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.95)',
  },
});
