// @vitest-environment nuxt
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { useNotify } from './useNotify';

describe('useNotify', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    const { notifications } = useNotify();
    notifications.value.splice(0, notifications.value.length);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('alert() adds a notification with defaults', () => {
    const { alert, notifications } = useNotify();
    alert({ message: 'Hello' });

    expect(notifications.value).toHaveLength(1);
    expect(notifications.value[0]).toMatchObject({
      type: 'alert',
      message: 'Hello',
      state: 'info',
    });
    expect(notifications.value[0]).not.toHaveProperty('visible');
  });

  it('alert() uses provided state and title', () => {
    const { alert, notifications } = useNotify();
    alert({ title: 'Oops', message: 'Broken', state: 'error' });

    expect(notifications.value[0]).toMatchObject({
      title: 'Oops',
      state: 'error',
    });
  });

  it('alert() auto-dismisses after 4 seconds', () => {
    const { alert, notifications } = useNotify();
    alert({ message: 'bye' });
    expect(notifications.value).toHaveLength(1);

    vi.advanceTimersByTime(4000);
    expect(notifications.value).toHaveLength(0);
  });

  it('confirm() adds a confirm notification and does not auto-dismiss', () => {
    const { confirm, notifications } = useNotify();
    const onConfirm = vi.fn();
    confirm({ question: 'Sure?', onConfirm });

    expect(notifications.value[0]).toMatchObject({
      type: 'confirm',
      message: 'Sure?',
      onConfirm,
    });
    expect(notifications.value[0]).not.toHaveProperty('visible');

    vi.advanceTimersByTime(10000);
    expect(notifications.value).toHaveLength(1);
  });

  it('dismiss() removes the notification with the given id', () => {
    const { alert, dismiss, notifications } = useNotify();
    alert({ message: 'a' });
    alert({ message: 'b' });
    const firstId = notifications.value[0]!.id;

    dismiss(firstId);

    expect(notifications.value).toHaveLength(1);
    expect(notifications.value[0]!.message).toBe('b');
  });

  it('dismiss() is a no-op for unknown ids', () => {
    const { alert, dismiss, notifications } = useNotify();
    alert({ message: 'a' });
    dismiss(9999);
    expect(notifications.value).toHaveLength(1);
  });

  it('shares state across calls to useNotify', () => {
    const a = useNotify();
    const b = useNotify();
    a.alert({ message: 'shared' });
    expect(b.notifications.value).toHaveLength(1);
  });
});
