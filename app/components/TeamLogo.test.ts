// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import TeamLogo from './TeamLogo.vue';

describe('TeamLogo', () => {
  it('renders empty background when no team is provided', () => {
    const wrapper = mount(TeamLogo);
    expect(wrapper.find('.team-logo').attributes('style')).toContain('url("")');
  });

  it('resolves flag:* to /flags/<key>.svg', () => {
    const wrapper = mount(TeamLogo, { props: { team: { image_url: 'flag:se' } } });
    expect(wrapper.find('.team-logo').attributes('style')).toContain('url("/flags/se.svg")');
  });

  it('resolves pl:* to /pl/<key>.png', () => {
    const wrapper = mount(TeamLogo, { props: { team: { image_url: 'pl:arsenal' } } });
    expect(wrapper.find('.team-logo').attributes('style')).toContain('url("/pl/arsenal.png")');
  });

  it('returns empty url for unknown types', () => {
    const wrapper = mount(TeamLogo, { props: { team: { image_url: 'unknown:foo' } } });
    expect(wrapper.find('.team-logo').attributes('style')).toContain('url("")');
  });
});
