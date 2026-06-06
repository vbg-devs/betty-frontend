// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { nextTick } from 'vue';
import { useNotify } from '../composables/useNotify';
import NotificationProvider from './NotificationProvider.vue';

function mountProvider() {
  return mount(NotificationProvider, {
    global: { stubs: { teleport: true } },
  });
}

describe('NotificationProvider', () => {
  beforeEach(() => {
    const { notifications } = useNotify();
    notifications.value.splice(0, notifications.value.length);
  });

  it('renders nothing when there are no notifications', () => {
    const wrapper = mountProvider();
    expect(wrapper.find('.notification-container').exists()).toBe(false);
  });

  it('renders an alert with title, message, default info state, and close button', async () => {
    const wrapper = mountProvider();
    useNotify().alert({ title: 'Saved', message: 'All good' });
    await nextTick();

    const notification = wrapper.find('.notification');
    expect(notification.exists()).toBe(true);
    expect(notification.classes()).toContain('notification--info');
    expect(notification.find('.notification__kicker').text()).toContain('BETTY SAYS');
    expect(notification.find('.notification__title').text()).toBe('Saved');
    expect(notification.find('.notification__message').text()).toBe('All good');
    expect(notification.find('.notification__close').exists()).toBe(true);
    expect(notification.find('.notification__actions').exists()).toBe(false);
  });

  it('omits the title element when the notification has no title', async () => {
    const wrapper = mountProvider();
    useNotify().alert({ message: 'no title here' });
    await nextTick();

    expect(wrapper.find('.notification__title').exists()).toBe(false);
    expect(wrapper.find('.notification__message').text()).toBe('no title here');
  });

  it('renders the message as HTML', async () => {
    const wrapper = mountProvider();
    useNotify().alert({ message: 'Hello <strong>you</strong>' });
    await nextTick();

    expect(wrapper.find('.notification__message strong').text()).toBe('you');
  });

  it.each([
    ['success', 'NICE'],
    ['error', 'OOPS'],
    ['warning', 'HEADS UP'],
  ] as const)('applies state class and kicker for %s alerts', async (state, kicker) => {
    const wrapper = mountProvider();
    useNotify().alert({ message: 'm', state });
    await nextTick();

    const notification = wrapper.find('.notification');
    expect(notification.classes()).toContain(`notification--${state}`);
    expect(notification.find('.notification__kicker').text()).toContain(kicker);
  });

  it('falls back to the info class when state is missing', async () => {
    const wrapper = mountProvider();
    const { notifications } = useNotify();
    notifications.value.push({ id: 9001, type: 'alert', message: 'raw', visible: true });
    await nextTick();

    expect(wrapper.find('.notification').classes()).toContain('notification--info');
    expect(wrapper.find('.notification__kicker').text()).toContain('BETTY SAYS');
  });

  it('renders multiple notifications in insertion order', async () => {
    const wrapper = mountProvider();
    const { alert } = useNotify();
    alert({ message: 'first' });
    alert({ message: 'second' });
    await nextTick();

    const messages = wrapper.findAll('.notification__message');
    expect(messages).toHaveLength(2);
    expect(messages[0]!.text()).toBe('first');
    expect(messages[1]!.text()).toBe('second');
  });

  it('dismisses an alert when the close button is clicked', async () => {
    const wrapper = mountProvider();
    const { alert, notifications } = useNotify();
    alert({ message: 'a' });
    alert({ message: 'b' });
    await nextTick();

    await wrapper.findAll('.notification__close')[0]!.trigger('click');

    expect(notifications.value).toHaveLength(1);
    expect(notifications.value[0]!.message).toBe('b');
    expect(wrapper.findAll('.notification')).toHaveLength(1);
    expect(wrapper.find('.notification__message').text()).toBe('b');
  });

  it('renders confirm notifications with action buttons instead of a close button', async () => {
    const wrapper = mountProvider();
    useNotify().confirm({ question: 'Delete it?', onConfirm: vi.fn() });
    await nextTick();

    const notification = wrapper.find('.notification');
    expect(notification.find('.notification__kicker').text()).toContain('HEADS UP');
    expect(notification.find('.notification__message').text()).toBe('Delete it?');
    expect(notification.find('.notification__close').exists()).toBe(false);
    expect(notification.find('.btn--ghost').text()).toBe('CANCEL');
    expect(notification.find('.btn--orange').text()).toContain('YES, DO IT');
  });

  it('uses the confirm kicker even when the notification has a state', async () => {
    const wrapper = mountProvider();
    const { notifications } = useNotify();
    notifications.value.push({
      id: 9002,
      type: 'confirm',
      message: 'sure?',
      state: 'success',
      onConfirm: vi.fn(),
      visible: true,
    });
    await nextTick();

    expect(wrapper.find('.notification__kicker').text()).toContain('HEADS UP');
  });

  it('cancel dismisses the confirm without calling onConfirm', async () => {
    const wrapper = mountProvider();
    const onConfirm = vi.fn();
    const { confirm, notifications } = useNotify();
    confirm({ question: 'Sure?', onConfirm });
    await nextTick();

    await wrapper.find('.btn--ghost').trigger('click');

    expect(onConfirm).not.toHaveBeenCalled();
    expect(notifications.value).toHaveLength(0);
    expect(wrapper.find('.notification').exists()).toBe(false);
  });

  it('confirm button calls onConfirm and then dismisses', async () => {
    const wrapper = mountProvider();
    const onConfirm = vi.fn();
    const { confirm, notifications } = useNotify();
    confirm({ question: 'Sure?', onConfirm });
    await nextTick();

    await wrapper.find('.btn--orange').trigger('click');
    await flushPromises();

    expect(onConfirm).toHaveBeenCalledTimes(1);
    expect(notifications.value).toHaveLength(0);
    expect(wrapper.find('.notification').exists()).toBe(false);
  });

  it('waits for an async onConfirm before dismissing', async () => {
    const wrapper = mountProvider();
    let resolveConfirm!: () => void;
    const onConfirm = vi.fn(
      () =>
        new Promise<void>((resolve) => {
          resolveConfirm = resolve;
        }),
    );
    const { confirm, notifications } = useNotify();
    confirm({ question: 'Slow?', onConfirm });
    await nextTick();

    await wrapper.find('.btn--orange').trigger('click');
    expect(onConfirm).toHaveBeenCalledTimes(1);
    expect(notifications.value).toHaveLength(1);

    resolveConfirm();
    await flushPromises();
    expect(notifications.value).toHaveLength(0);
  });

  it('handles a confirm notification without onConfirm by just dismissing', async () => {
    const wrapper = mountProvider();
    const { notifications } = useNotify();
    notifications.value.push({ id: 9003, type: 'confirm', message: 'orphan', visible: true });
    await nextTick();

    await wrapper.find('.btn--orange').trigger('click');
    await flushPromises();

    expect(notifications.value).toHaveLength(0);
  });
});
