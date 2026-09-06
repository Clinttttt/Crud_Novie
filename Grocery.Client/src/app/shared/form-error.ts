import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { AbstractControl } from '@angular/forms';

/** One line of red text under a field, shown only after the user has touched it. */
@Component({
  selector: 'app-form-error',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (control().touched && control().invalid) {
      <small class="field-error">
        @if (control().hasError('required') || control().hasError('blank')) {
          {{ label() }} is required.
        } @else if (control().hasError('maxlength')) {
          {{ label() }} is too long.
        } @else if (control().hasError('pattern')) {
          Use letters, numbers, and dashes only.
        } @else if (control().hasError('min')) {
          {{ label() }} cannot be negative.
        } @else {
          Enter a valid {{ label().toLowerCase() }}.
        }
      </small>
    }
  `,
})
export class FormError {
  readonly control = input.required<AbstractControl>();
  readonly label = input.required<string>();
}
