// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import ProgressBar from './ProgressBar.vue';

describe('ProgressBar', () => {
  it('defaults progress to 0%', () => {
    const wrapper = mount(ProgressBar);
    const bar = wrapper.find('.progress-bar__progress');
    expect(bar.attributes('style')).toContain('width: 0%');
  });

  it('renders the given progress width', () => {
    const wrapper = mount(ProgressBar, { props: { progress: 42 } });
    const bar = wrapper.find('.progress-bar__progress');
    expect(bar.attributes('style')).toContain('width: 42%');
  });
});
