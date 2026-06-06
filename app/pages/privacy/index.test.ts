// @vitest-environment nuxt
import { describe, it, expect, beforeAll } from 'vitest';
import { mount, type VueWrapper } from '@vue/test-utils';
import PrivacyPage from './index.vue';

describe('privacy page', () => {
  let wrapper: VueWrapper;

  beforeAll(() => {
    wrapper = mount(PrivacyPage);
  });

  it('renders the hero with kicker, title and last-updated date', () => {
    expect(wrapper.find('.kicker--accent').text()).toBe('★ THE FINE PRINT');
    expect(wrapper.find('.hero__title').text()).toBe('PRIVACYPOLICY.');
    expect(wrapper.find('.hero__meta').text()).toBe('Last updated · September 24, 2022');
  });

  it('renders all top-level policy sections in order', () => {
    const headings = wrapper.findAll('.privacy-page__body h1').map((h) => h.text());
    expect(headings).toEqual([
      'Interpretation and Definitions',
      'Collecting and Using Your Personal Data',
      'Detailed Information on the Processing of Your Personal Data',
      "Children's Privacy",
      'Links to Other Websites',
      'Changes to this Privacy Policy',
      'Contact Us',
    ]);
  });

  it('defines the key terms with company and country details', () => {
    const definitions = wrapper.findAll('.privacy-page__body ul li strong').map((s) => s.text());
    expect(definitions).toContain('Account');
    expect(definitions).toContain('Company');
    expect(definitions).toContain('Personal Data');
    expect(definitions).toContain('Usage Data');

    const body = wrapper.find('.privacy-page__body').text();
    expect(body).toContain('refers to Betty Social');
    expect(body).toContain('Country refers to: Sweden');
  });

  it('lists the collected personally identifiable information', () => {
    const body = wrapper.find('.privacy-page__body').text();
    expect(body).toContain('Email address');
    expect(body).toContain('First name and last name');
  });

  it('links to the privacy policy generator opening in a new tab', () => {
    const link = wrapper.find(
      'a[href="https://www.freeprivacypolicy.com/free-privacy-policy-generator/"]',
    );
    expect(link.exists()).toBe(true);
    expect(link.attributes('target')).toBe('_blank');
  });

  it('links to the Firebase privacy policy with safe rel attributes', () => {
    const link = wrapper.find('a[href="https://firebase.google.com/support/privacy"]');
    expect(link.exists()).toBe(true);
    expect(link.attributes('target')).toBe('_blank');
    expect(link.attributes('rel')).toBe('external nofollow noopener');
  });

  it('states the minimum age and notice-of-change policy', () => {
    const body = wrapper.find('.privacy-page__body').text();
    expect(body).toContain('does not address anyone under the age of 13');
    expect(body).toContain('We will notify You of any changes by posting the new Privacy Policy');
  });

  it('shows the contact email', () => {
    expect(wrapper.find('.privacy-page__body').text()).toContain('By email: privacy@betty.social');
  });
});
