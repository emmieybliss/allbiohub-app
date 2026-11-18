import { appPathFor } from '@/lib/deepLinks';
import { redirectSystemPath } from '@/app/+native-intent';

const host = 'allbiohub.com';

it.each([
  ['https://allbiohub.com/', '/'],
  ['https://www.allbiohub.com/wizkid-net-worth/', '/story/wizkid-net-worth'],
  ['https://allbiohub.com/startups/', '/startups'],
  ['https://allbiohub.com/startups/page/2/', '/startups'],
  ['https://allbiohub.com/startups/paystack/', '/startup/paystack'],
  ['https://allbiohub.com/category/celebrity-news/', '/category/celebrity-news'],
  ['https://allbiohub.com/category/parent/child/page/2/', '/category/child'],
  ['https://allbiohub.com/category/', '/discover'],
  ['https://allbiohub.com/tag/afrobeats/', '/tag/afrobeats'],
])('opens %s at %s', (url, path) => {
  expect(appPathFor(url, host)).toBe(path);
});

it.each([
  'https://allbiohub.com/list-your-startup/',
  'https://allbiohub.com/wp-admin/',
  'https://allbiohub.com/sitemap_index.xml',
  'https://allbiohub.com/privacy-policy/',
  'https://allbiohub.com/a/b/',
  'https://example.com/story/',
  'not a url',
])('leaves %s to the browser', (url) => {
  expect(appPathFor(url, host)).toBeNull();
});

describe('incoming links', () => {
  it.each([
    ['https://allbiohub.com/wizkid-net-worth/', '/story/wizkid-net-worth'],
    ['https://allbiohub.com/claim-startup/', '/'],
    ['/article/12', '/article/12'],
    ['/startup/paystack', '/startup/paystack'],
    ['/wizkid-net-worth/', '/story/wizkid-net-worth'],
    ['/startups/paystack/', '/startup/paystack'],
    ['allbiohub://article/12', '/article/12'],
  ])('%s → %s', (path, expected) => {
    expect(redirectSystemPath({ path, initial: true })).toBe(expected);
  });
});
