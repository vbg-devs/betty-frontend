// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import GroupJoinedListItem from './GroupJoinedListItem.vue';

describe('GroupJoinedListItem', () => {
  it('renders the joiner name and group name', () => {
    const wrapper = mount(GroupJoinedListItem, {
      props: { data: { who: 'Alice', group: { name: 'Premier League' } } },
    });
    const strongs = wrapper.findAll('strong');
    expect(strongs[0]!.text()).toBe('Alice');
    expect(strongs[1]!.text()).toBe('Premier League');
    expect(wrapper.text()).toBe('Alice just joined Premier League');
  });

  it("falls back to 'Someone' when who is missing", () => {
    const wrapper = mount(GroupJoinedListItem, {
      props: { data: { group: { name: 'Office Pool' } } },
    });
    expect(wrapper.text()).toBe('Someone just joined Office Pool');
  });

  it("falls back to 'Someone' when who is an empty string", () => {
    const wrapper = mount(GroupJoinedListItem, {
      props: { data: { who: '', group: { name: 'Office Pool' } } },
    });
    expect(wrapper.findAll('strong')[0]!.text()).toBe('Someone');
  });

  it('renders an empty group name when group.name is missing', () => {
    const wrapper = mount(GroupJoinedListItem, {
      props: { data: { who: 'Bob', group: {} } },
    });
    expect(wrapper.findAll('strong')[1]!.text()).toBe('');
    expect(wrapper.text()).toBe('Bob just joined');
  });

  it('renders without a group name when the data prop is omitted', () => {
    const wrapper = mount(GroupJoinedListItem);
    expect(wrapper.text()).toBe('Someone just joined');
    expect(wrapper.findAll('strong')[1]!.text()).toBe('');
  });

  it('renders without a group name when data has no group', () => {
    const wrapper = mount(GroupJoinedListItem, { props: { data: { who: 'Eve' } } });
    expect(wrapper.text()).toBe('Eve just joined');
    expect(wrapper.findAll('strong')[1]!.text()).toBe('');
  });
});
