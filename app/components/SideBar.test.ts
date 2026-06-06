// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import SideBar from './SideBar.vue';

// ActivityFeed opens a WebSocket on mount; stub it to keep tests offline.
const mountSideBar = (props: { show?: boolean } = {}) =>
  mount(SideBar, {
    props,
    global: { stubs: { ActivityFeed: true } },
  });

describe('SideBar', () => {
  it('renders an aside without the show modifier by default', () => {
    const wrapper = mountSideBar();
    expect(wrapper.element.tagName).toBe('ASIDE');
    expect(wrapper.classes()).toContain('side-bar');
    expect(wrapper.classes()).not.toContain('side-bar--show');
  });

  it('treats an explicit show=false the same as the default', () => {
    const wrapper = mountSideBar({ show: false });
    expect(wrapper.classes()).not.toContain('side-bar--show');
  });

  it('applies the show modifier when show=true', () => {
    const wrapper = mountSideBar({ show: true });
    expect(wrapper.classes()).toContain('side-bar--show');
  });

  it('toggles the show modifier reactively when the prop changes', async () => {
    const wrapper = mountSideBar({ show: false });
    expect(wrapper.classes()).not.toContain('side-bar--show');

    await wrapper.setProps({ show: true });
    expect(wrapper.classes()).toContain('side-bar--show');

    await wrapper.setProps({ show: false });
    expect(wrapper.classes()).not.toContain('side-bar--show');
  });

  it('renders the ActivityFeed inside the inner section', () => {
    const wrapper = mountSideBar();
    const inner = wrapper.find('.side-bar__inner');
    expect(inner.element.tagName).toBe('SECTION');
    expect(inner.find('activity-feed-stub').exists()).toBe(true);
  });
});
