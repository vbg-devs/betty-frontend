// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import HiddenScore from './HiddenScore.vue';

describe('HiddenScore', () => {
  it('renders two eye-off icons separated by a dash', () => {
    const wrapper = mount(HiddenScore);
    expect(wrapper.findAll('svg.feather-eye-off')).toHaveLength(2);
    expect(wrapper.text()).toContain('-');
  });
});
