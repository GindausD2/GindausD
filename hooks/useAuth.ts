import { useState, useEffect } from 'react';
import { getAuthUser, AuthUser } from '@/services/auth';

export function useAuth() {
  // undefined = still loading; null = not authenticated; AuthUser = authenticated
  const [user, setUser] = useState<AuthUser | null | undefined>(undefined);

  useEffect(() => {
    getAuthUser().then(setUser);
  }, []);

  const isLoading = user === undefined;
  const isAuthenticated = user !== null && user !== undefined;

  return { user, isLoading, isAuthenticated, setUser };
}
