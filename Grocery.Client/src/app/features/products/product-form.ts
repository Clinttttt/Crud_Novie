import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  input,
  output,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, ValidatorFn, Validators } from '@angular/forms';
import { FormError } from '@shared/form-error';
import { Product, ProductInput } from './product.model';

/** Rejects a value that is only spaces, which Validators.required would let through. */
const notBlank: ValidatorFn = (control) => {
  const value = control.value as string | null;
  return value !== null && value !== '' && !value.trim() ? { blank: true } : null;
};

const MAX = 1_000_000;

/**
 * The add/edit form. It owns its validation rules and knows nothing about HTTP: when the
 * user submits, it emits the values and lets the page decide whether that is a create or
 * an update.
 */
@Component({
  selector: 'app-product-form',
  imports: [ReactiveFormsModule, FormError],
  templateUrl: './product-form.html',
  styleUrl: './product-form.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProductForm {
  private readonly fb = inject(FormBuilder);

  readonly editing = input<Product | null>(null);
  readonly saving = input(false);
  readonly busy = input(false);

  readonly save = output<ProductInput>();
  readonly cancelled = output<void>();

  readonly isEditing = computed(() => this.editing() !== null);

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, notBlank, Validators.maxLength(120)]],
    barcode: [
      '',
      [Validators.required, Validators.maxLength(32), Validators.pattern(/^[A-Za-z0-9-]+$/)],
    ],
    category: ['', Validators.maxLength(60)],
    quantity: [0, [Validators.required, Validators.min(0), Validators.max(MAX)]],
    reorderLevel: [0, [Validators.required, Validators.min(0), Validators.max(MAX)]],
    wholesalePrice: [0, [Validators.required, Validators.min(0), Validators.max(MAX)]],
    retailPrice: [0, [Validators.required, Validators.min(0), Validators.max(MAX)]],
    expiryDate: [''],
  });

  constructor() {
    // Whenever the page picks a different product to edit, refill the fields.
    effect(() => this.reset(this.editing()));
  }

  submit(): void {
    this.form.markAllAsTouched();

    if (this.form.invalid || this.busy()) {
      return;
    }

    const values = this.form.getRawValue();

    this.save.emit({
      name: values.name.trim(),
      barcode: values.barcode.trim(),
      category: values.category.trim() || null,
      quantity: Number(values.quantity),
      reorderLevel: Number(values.reorderLevel),
      wholesalePrice: Number(values.wholesalePrice),
      retailPrice: Number(values.retailPrice),
      expiryDate: values.expiryDate || null,
    });
  }

  reset(product: Product | null = null): void {
    this.form.reset({
      name: product?.name ?? '',
      barcode: product?.barcode ?? '',
      category: product?.category ?? '',
      quantity: product?.quantity ?? 0,
      reorderLevel: product?.reorderLevel ?? 0,
      wholesalePrice: product?.wholesalePrice ?? 0,
      retailPrice: product?.retailPrice ?? 0,
      expiryDate: product?.expiryDate ?? '',
    });
  }
}
