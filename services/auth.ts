import AsyncStorage from '@react-native-async-storage/async-storage';

const AUTH_KEY = 'max:auth_user';

export interface AuthUser {
  name?: string;
  email?: string;
  isDemo?: boolean;
}

export async function getAuthUser(): Promise<AuthUser | null> {
  try {
    const raw = await AsyncStorage.getItem(AUTH_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export async function signIn(email: string, _password: string): Promise<AuthUser> {
  const user: AuthUser = { email: email.toLowerCase().trim() };
  await AsyncStorage.setItem(AUTH_KEY, JSON.stringify(user));
  return user;
}

export async function signUp(name: string, email: string, _password: string): Promise<AuthUser> {
  const user: AuthUser = { name: name.trim(), email: email.toLowerCase().trim() };
  await AsyncStorage.setItem(AUTH_KEY, JSON.stringify(user));
  return user;
}

export async function startDemo(): Promise<AuthUser> {
  const user: AuthUser = { isDemo: true, name: 'Guest' };
  await AsyncStorage.setItem(AUTH_KEY, JSON.stringify(user));
  return user;
}

export async function signOut(): Promise<void> {
  await AsyncStorage.removeItem(AUTH_KEY);
}
