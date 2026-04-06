import { create } from 'zustand';

interface AuthState {
  token: string | null;
  setToken: (token: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>(set => ({
  token: localStorage.getItem('accessToken'),
  setToken: (token) => {
    localStorage.setItem('accessToken', token);
    set({ token });
  },
  logout: () => {
    localStorage.removeItem('accessToken');
    set({ token: null });
  },
}));
