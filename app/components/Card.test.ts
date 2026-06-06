// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import Card from './Card.vue';

describe('Card', () => {
  it('renders default, header, top and footer slots', () => {
    const wrapper = mount(Card, {
      slots: {
        default: '<p class="body">body</p>',
        header: '<p class="h">h</p>',
        top: '<p class="t">t</p>',
        footer: '<p class="f">f</p>',
      },
    });
    expect(wrapper.find('.card__header .h').exists()).toBe(true);
    expect(wrapper.find('.t').exists()).toBe(true);
    expect(wrapper.find('.card__body .body').exists()).toBe(true);
    expect(wrapper.find('.card__footer .f').exists()).toBe(true);
  });

  it('applies no-padding modifier when noPadding prop is true', () => {
    const wrapper = mount(Card, { props: { noPadding: true }, slots: { default: 'body' } });
    expect(wrapper.find('.card__body').classes()).toContain('card__body--no-padding');
  });

  it('does not apply no-padding modifier by default', () => {
    const wrapper = mount(Card, { slots: { default: 'body' } });
    expect(wrapper.find('.card__body').classes()).not.toContain('card__body--no-padding');
  });

  it('omits the body section when no default slot is given', () => {
    const wrapper = mount(Card);
    expect(wrapper.find('.card__body').exists()).toBe(false);
  });

  it('emits "clicked" when the card is clicked', async () => {
    const wrapper = mount(Card);
    await wrapper.trigger('click');
    expect(wrapper.emitted('clicked')).toHaveLength(1);
  });
});
