// 허용: features → entities (public API), features → shared (public API)
import type { Task } from '@/entities/task';
import { u } from '@/shared';
export const CreateTask = (_t: Task) => u;
