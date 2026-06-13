// 금지: components → services (alias), components → app (상대경로)
import { api } from '@/services/api';
import { boot } from '../app/main';
export const Bad = () => api() ?? boot();
