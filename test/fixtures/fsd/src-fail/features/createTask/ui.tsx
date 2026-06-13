// 금지 3종: layer 위반(features→widgets), cross-slice(features/createTask→features/deleteTask),
//          public-api 위반(entities/task 내부 파일 직접 import)
import { W } from '@/widgets/panel';
import { D } from '@/features/deleteTask';
import { M } from '@/entities/task/model';
export const CreateTask = () => [W, D, M];
