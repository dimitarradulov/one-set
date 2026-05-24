import { dismissCreateAccountPrompt } from '../create-account-dismissal';

const FALLBACK_HREF = '/recommended-program';

describe('create-account dismissal', () => {
  test('uses history-backed dismissal when navigation can go back', () => {
    const navigation = {
      canGoBack: jest.fn(() => true),
      back: jest.fn(),
      replace: jest.fn(),
    };

    dismissCreateAccountPrompt(navigation);

    expect(navigation.canGoBack).toHaveBeenCalledTimes(1);
    expect(navigation.back).toHaveBeenCalledTimes(1);
    expect(navigation.replace).not.toHaveBeenCalled();
  });

  test('falls back to Program Recommendation when no navigation history exists', () => {
    const navigation = {
      canGoBack: jest.fn(() => false),
      back: jest.fn(),
      replace: jest.fn(),
    };

    dismissCreateAccountPrompt(navigation);

    expect(navigation.canGoBack).toHaveBeenCalledTimes(1);
    expect(navigation.back).not.toHaveBeenCalled();
    expect(navigation.replace).toHaveBeenCalledWith(FALLBACK_HREF);
  });
});
