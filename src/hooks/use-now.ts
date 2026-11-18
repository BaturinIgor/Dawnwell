import { useEffect, useState } from 'react';

/**
 * Current time for rendering. Ticks every second until `fastUntil` (ms epoch),
 * then once a minute, so screens can show countdowns without re-rendering all day.
 */
export function useNow(fastUntil: number | null = null): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>;
    const tick = () => {
      const t = Date.now();
      setNow(t);
      const fast = fastUntil !== null && t < fastUntil;
      timer = setTimeout(tick, fast ? Math.min(1000, fastUntil - t) : 60_000);
    };
    timer = setTimeout(tick, 0);
    return () => clearTimeout(timer);
  }, [fastUntil]);
  return now;
}
