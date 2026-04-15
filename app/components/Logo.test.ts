// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import Logo from './Logo.vue';

describe('Logo', () => {
  it('renders an svg with the NuxtLogo class', () => {
    const wrapper = mount(Logo);
    const svg = wrapper.find('svg');
    expect(svg.exists()).toBe(true);
    expect(svg.classes()).toContain('NuxtLogo');
  });
});
