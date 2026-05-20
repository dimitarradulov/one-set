import { fireEvent, render, screen } from '@testing-library/react-native';

import AssessmentQuestion from '@/components/AssessmentQuestion';

const options = [
  { label: 'Build muscle', value: 'build_muscle' },
  { label: 'Get stronger', value: 'get_stronger' },
  { label: 'Recomp my body', value: 'recomp' },
] as const;

describe('AssessmentQuestion', () => {
  test('renders passed assessment question content and progress', () => {
    render(
      <AssessmentQuestion
        continueDisabled
        continueLabel="Continue"
        helperText="Pick the result you care about most right now."
        options={options}
        progressStep={1}
        selectedValues={[]}
        totalSteps={11}
        question="What is your main goal right now?"
        onContinue={jest.fn()}
        onSelectOption={jest.fn()}
      />
    );

    expect(screen.getByText('Question 1 of 11')).toBeOnTheScreen();
    expect(
      screen.getByRole('progressbar', { value: { min: 0, max: 11, now: 1 } })
    ).toBeOnTheScreen();
    expect(
      screen.getByRole('header', { name: 'What is your main goal right now?' })
    ).toBeOnTheScreen();
    expect(screen.getByText('Pick the result you care about most right now.')).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Build muscle' })).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Get stronger' })).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Recomp my body' })).toBeOnTheScreen();
  });

  test('renders the question body inside a scroll container while keeping Continue visible', () => {
    render(
      <AssessmentQuestion
        continueDisabled={false}
        continueLabel="Continue"
        helperText="Pick one."
        options={options}
        progressStep={1}
        selectedValues={[]}
        totalSteps={11}
        question="Question?"
        onContinue={jest.fn()}
        onSelectOption={jest.fn()}
      />
    );

    expect(screen.getByTestId('assessment-question-scroll')).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeOnTheScreen();
  });

  test('exposes selected option state and a visible checkmark', () => {
    render(
      <AssessmentQuestion
        continueDisabled={false}
        continueLabel="Continue"
        helperText="Pick one."
        options={options}
        progressStep={1}
        selectedValues={['get_stronger']}
        totalSteps={11}
        question="Question?"
        onContinue={jest.fn()}
        onSelectOption={jest.fn()}
      />
    );

    expect(screen.getByRole('button', { name: 'Get stronger' })).toBeSelected();
    expect(screen.getByText('✓')).toBeOnTheScreen();
  });

  test('calls option, Continue, and Back callbacks when enabled', () => {
    const onBack = jest.fn();
    const onContinue = jest.fn();
    const onSelectOption = jest.fn();

    render(
      <AssessmentQuestion
        backLabel="Back"
        continueDisabled={false}
        continueLabel="Continue"
        helperText="Pick one."
        options={options}
        progressStep={1}
        selectedValues={[]}
        totalSteps={11}
        question="Question?"
        onBack={onBack}
        onContinue={onContinue}
        onSelectOption={onSelectOption}
      />
    );

    fireEvent.press(screen.getByRole('button', { name: 'Back' }));
    fireEvent.press(screen.getByRole('button', { name: 'Recomp my body' }));
    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(onBack).toHaveBeenCalledTimes(1);
    expect(onSelectOption).toHaveBeenCalledTimes(1);
    expect(onSelectOption).toHaveBeenCalledWith('recomp');
    expect(onContinue).toHaveBeenCalledTimes(1);
  });

  test('disables Back, option, and Continue interactions when requested', () => {
    const onBack = jest.fn();
    const onContinue = jest.fn();
    const onSelectOption = jest.fn();

    render(
      <AssessmentQuestion
        backLabel="Back"
        disabled
        continueDisabled={false}
        continueLabel="Continue"
        helperText="Pick one."
        options={options}
        progressStep={1}
        selectedValues={[]}
        totalSteps={11}
        question="Question?"
        onBack={onBack}
        onContinue={onContinue}
        onSelectOption={onSelectOption}
      />
    );

    fireEvent.press(screen.getByRole('button', { name: 'Back' }));
    fireEvent.press(screen.getByRole('button', { name: 'Build muscle' }));
    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(screen.getByRole('button', { name: 'Back' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Build muscle' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeDisabled();
    expect(onBack).not.toHaveBeenCalled();
    expect(onSelectOption).not.toHaveBeenCalled();
    expect(onContinue).not.toHaveBeenCalled();
  });

  test('exposes multi-select options as checkboxes', () => {
    render(
      <AssessmentQuestion
        continueDisabled={false}
        continueLabel="Continue"
        helperText="Select all that apply."
        options={options}
        progressStep={9}
        selectedValues={['build_muscle', 'recomp']}
        selectionMode="multiple"
        totalSteps={11}
        question="Question?"
        onContinue={jest.fn()}
        onSelectOption={jest.fn()}
      />
    );

    expect(screen.getByRole('checkbox', { name: 'Build muscle' })).toBeChecked();
    expect(screen.getByRole('checkbox', { name: 'Get stronger' })).not.toBeChecked();
    expect(screen.getByRole('checkbox', { name: 'Recomp my body' })).toBeChecked();
  });
});
