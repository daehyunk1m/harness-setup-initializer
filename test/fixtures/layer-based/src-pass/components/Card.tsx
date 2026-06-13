import { useThing } from '@/hooks/useThing';
import { u } from '@/lib/util';
export const Card = () => useThing() ?? u();
