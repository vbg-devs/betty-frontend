// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import SplitProgressBar from './SplitProgressBar.vue';

describe('SplitProgressBar', () => {
  it('defaults all three segments to 0%', () => {
    const wrapper = mount(SplitProgressBar);
    expect(wrapper.find('.progress-bar__progress--left').attributes('style')).toContain(
      'width: 0%'
    );
    expect(wrapper.find('.progress-bar__progress--center').attributes('style')).toContain(
      'width: 0%'
    );
    expect(wrapper.find('.progress-bar__progress--right').attributes('style')).toContain(
      'width: 0%'
    );
  });

  it('maps props to the correct segment widths', () => {
    const wrapper = mount(SplitProgressBar, {
      props: { leftProgress: 30, tieProgress: 20, rightProgress: 50 },
    });
    expect(wrapper.find('.progress-bar__progress--left').attributes('style')).toContain(
      'width: 30%'
    );
    expect(wrapper.find('.progress-bar__progress--center').attributes('style')).toContain(
      'width: 20%'
    );
    expect(wrapper.find('.progress-bar__progress--right').attributes('style')).toContain(
      'width: 50%'
    );
  });
});
