// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import UserBadge from './UserBadge.vue';

describe('UserBadge', () => {
  it('shows image when user has image_url', () => {
    const wrapper = mount(UserBadge, {
      props: { user: { image_url: 'https://example.com/a.png' } },
    });
    const img = wrapper.find('.user-badge__image');
    expect(img.exists()).toBe(true);
    expect(img.attributes('style')).toContain('url("https://example.com/a.png")');
    expect(wrapper.find('.user-badge__initial').exists()).toBe(false);
  });

  it('shows initials from first and last name', () => {
    const wrapper = mount(UserBadge, { props: { user: { name: 'Jane Doe' } } });
    expect(wrapper.find('.user-badge__initial').text()).toBe('JD');
  });

  it('shows first letter when name has no space', () => {
    const wrapper = mount(UserBadge, { props: { user: { name: 'Madonna' } } });
    expect(wrapper.find('.user-badge__initial').text()).toBe('M');
  });

  it('renders empty when user has no name or image', () => {
    const wrapper = mount(UserBadge, { props: { user: {} } });
    expect(wrapper.find('.user-badge__initial').text()).toBe('');
  });

  it('applies size modifier classes', () => {
    const small = mount(UserBadge, { props: { small: true } });
    expect(small.classes()).toContain('user-badge--small');
    const large = mount(UserBadge, { props: { large: true } });
    expect(large.classes()).toContain('user-badge--large');
    const medium = mount(UserBadge, { props: { medium: true } });
    expect(medium.classes()).toContain('user-badge--medium');
  });

  it('is clickable by default and emits click', async () => {
    const wrapper = mount(UserBadge, { props: { user: { name: 'A' } } });
    expect(wrapper.classes()).toContain('user-badge--clickable');
    await wrapper.trigger('click');
    expect(wrapper.emitted('click')).toHaveLength(1);
  });

  it('drops clickable class when clickable=false', () => {
    const wrapper = mount(UserBadge, { props: { clickable: false } });
    expect(wrapper.classes()).not.toContain('user-badge--clickable');
  });

  it('applies block class when block=true', () => {
    const wrapper = mount(UserBadge, { props: { block: true } });
    expect(wrapper.classes()).toContain('block');
  });
});
