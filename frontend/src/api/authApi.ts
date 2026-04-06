import { apiClient } from './client';
import type { AuthResponse } from '../types';

export const authApi = {
  register: (email: string, password: string, fullName: string) =>
    apiClient.post<AuthResponse>('/api/auth/register', { email, password, fullName }),
  login: (email: string, password: string) =>
    apiClient.post<AuthResponse>('/api/auth/login', { email, password }),
};
