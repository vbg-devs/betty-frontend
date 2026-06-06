// @vitest-environment nuxt
import { describe, it, expect, beforeEach } from 'vitest';
import { mount, type VueWrapper } from '@vue/test-utils';
import AboutPage from './index.vue';

describe('pages/about', () => {
  let wrapper: VueWrapper;

  beforeEach(() => {
    wrapper = mount(AboutPage);
  });

  it('renders the hero with title, kicker, badge and lede', () => {
    expect(wrapper.find('.hero__title').text()).toContain("HI, I'M");
    expect(wrapper.find('.hero__title .t-green').text()).toBe('BETTY.');
    expect(wrapper.find('.hero__copy .kicker--accent').text()).toBe('★ ABOUT BETTY');
    expect(wrapper.find('.hero__badge').text()).toBe("★ HI, I'M BETTY");
    expect(wrapper.find('.hero__lede').text()).toContain('tournament predictions');
  });

  it('renders the hero video looping muted with poster and mp4 source', () => {
    const video = wrapper.find('video.hero__video');
    expect(video.exists()).toBe(true);
    expect(video.attributes('poster')).toBe('/poster--new.jpg');
    expect(video.attributes('autoplay')).toBeDefined();
    expect(video.attributes('loop')).toBeDefined();
    expect(video.attributes('playsinline')).toBeDefined();
    expect((video.element as HTMLVideoElement).muted).toBe(true);

    const source = video.find('source');
    expect(source.attributes('src')).toBe('/betty-alive--new.mp4');
    expect(source.attributes('type')).toBe('video/mp4');
  });

  it('renders the WHAT card with orange accent', () => {
    const card = wrapper.find('.info-card--orange');
    expect(card.find('.kicker').text()).toBe('★ WHAT');
    expect(card.find('.info-card__title').text()).toBe('A SOCIAL PREDICTIONS GAME.');
    expect(card.find('.info-card__copy').text()).toContain('free game for tournament predictions');
  });

  it('renders the WHO card with green accent', () => {
    const card = wrapper.find('.info-card--green');
    expect(card.find('.kicker--green').text()).toBe('● WHO');
    expect(card.find('.info-card__title').text()).toBe('YOUR SCOREKEEPER.');
    expect(card.find('.info-card__copy').text()).toContain('born in Varberg in 2021');
  });

  it('renders three how-it-works steps in order with numbers and titles', () => {
    expect(wrapper.find('.how__title').text()).toBe('THREE STEPS. NO FINE PRINT.');

    const steps = wrapper.findAll('.step');
    expect(steps).toHaveLength(3);

    expect(steps[0]!.find('.step__number').text()).toBe('01');
    expect(steps[0]!.find('.step__title').text()).toBe('Make a group');
    expect(steps[0]!.find('.kicker--accent').text()).toBe('★ SET');

    expect(steps[1]!.find('.step__number').text()).toBe('02');
    expect(steps[1]!.find('.step__title').text()).toBe('Lock the bets');
    expect(steps[1]!.find('.kicker--green').text()).toBe('● BET');

    expect(steps[2]!.find('.step__number').text()).toBe('03');
    expect(steps[2]!.find('.step__title').text()).toBe('Climb the board');
    expect(steps[2]!.find('.kicker--yellow').text()).toBe('★ WIN');
  });

  it('renders four tips with bolded leads', () => {
    const tips = wrapper.find('.tips');
    expect(tips.find('.info-card__title').text()).toBe('GETTING THE MOST OUT OF BETTY.');

    const items = tips.findAll('.tips__list li');
    expect(items).toHaveLength(4);
    expect(items.map((li) => li.find('strong').text())).toEqual([
      'Invite early.',
      'Set points that match the vibe.',
      'Use the group chat.',
      'Check the global leaderboard.',
    ]);
  });
});
