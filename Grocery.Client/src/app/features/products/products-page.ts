import {
  ChangeDetectionStrategy,
  Component,
  computed,
  DestroyRef,
  inject,
  OnInit,
  signal,
  viewChild,
  WritableSignal,
} from '@angular/core';
import { CurrencyPipe, DatePipe } from '@angular/common';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { debounceTime, finalize, Observable, Subject } from 'rxjs';
import { ProductForm } from './product-form';
import { Product, ProductInput, StockFilter } from './product.model';
import { ProductService } from './product.service';

interface Feedback {
  kind: 'error' | 'success';
  text: string;
}

/** How the expiry date is shown in the table. */
type ExpiryState = 'none' | 'expired' | 'soon' | 'ok';

/** Same window the API uses for its "Expiring" filter. */
const EXPIRING_SOON_DAYS = 30;

/** Local calendar date as "YYYY-MM-DD", which is also how the API sends dates. */
const isoDate = (date: Date): string => {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
};

/**
 * The container for the whole feature: it holds the state, calls the service, and renders
 * the stock table. The form is a child component because it owns its own validation.
 */
@Component({
  selector: 'app-products-page',
  imports: [ProductForm, CurrencyPipe, DatePipe],
  templateUrl: './products-page.html',
  styleUrl: './products-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProductsPage implements OnInit {
  private readonly api = inject(ProductService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly productForm = viewChild.required(ProductForm);
  private readonly searchInput = new Subject<void>();

  readonly products = signal<Product[]>([]);
  readonly search = signal('');
  readonly filter = signal<StockFilter>('All');
  readonly editing = signal<Product | null>(null);
  readonly pendingDelete = signal<Product | null>(null);
  readonly loading = signal(false);
  readonly saving = signal(false);
  readonly deleting = signal(false);
  readonly feedback = signal<Feedback | null>(null);

  readonly busy = computed(() => this.loading() || this.saving() || this.deleting());

  readonly lowStockCount = computed(
    () => this.products().filter((product) => this.isLowStock(product)).length,
  );

  readonly expiringCount = computed(
    () =>
      this.products().filter((product) => {
        const state = this.expiryState(product);
        return state === 'expired' || state === 'soon';
      }).length,
  );

  /** What the stock on hand would earn at retail price. */
  readonly retailValue = computed(() =>
    this.products().reduce((total, product) => total + product.quantity * product.retailPrice, 0),
  );

  readonly filters: { value: StockFilter; label: string }[] = [
    { value: 'All', label: 'All stock' },
    { value: 'LowStock', label: 'Running low' },
    { value: 'Expiring', label: 'Expiring' },
  ];

  private readonly today = isoDate(new Date());
  private readonly soonCutoff = isoDate(
    new Date(Date.now() + EXPIRING_SOON_DAYS * 24 * 60 * 60 * 1000),
  );

  constructor() {
    // Wait until typing pauses before asking the API again.
    this.searchInput
      .pipe(debounceTime(300), takeUntilDestroyed())
      .subscribe(() => this.load());
  }

  ngOnInit(): void {
    this.load();
  }

  onSearch(value: string): void {
    this.search.set(value);
    this.searchInput.next();
  }

  clearSearch(): void {
    this.search.set('');
    this.load();
  }

  setFilter(filter: StockFilter): void {
    if (this.filter() === filter) {
      return;
    }

    this.filter.set(filter);
    this.load();
  }

  refresh(): void {
    this.feedback.set(null);
    this.load();
  }

  edit(product: Product): void {
    this.editing.set(product);
    this.pendingDelete.set(null);
    this.feedback.set(null);
  }

  cancelEdit(): void {
    this.editing.set(null);
    this.productForm().reset();
  }

  save(input: ProductInput): void {
    const editing = this.editing();
    const request: Observable<Product | void> = editing
      ? this.api.update(editing.id, input)
      : this.api.create(input);

    this.feedback.set(null);
    this.run(this.saving, request, () => {
      this.cancelEdit();
      this.load();
      this.feedback.set({
        kind: 'success',
        text: editing ? `${input.name} updated.` : `${input.name} added to the inventory.`,
      });
    });
  }

  askToDelete(product: Product): void {
    this.pendingDelete.set(product);
    this.feedback.set(null);
  }

  cancelDelete(): void {
    this.pendingDelete.set(null);
  }

  confirmDelete(): void {
    const product = this.pendingDelete();

    if (!product) {
      return;
    }

    this.run(this.deleting, this.api.delete(product.id), () => {
      this.products.update((current) => current.filter((item) => item.id !== product.id));

      if (this.editing()?.id === product.id) {
        this.cancelEdit();
      }

      this.pendingDelete.set(null);
      this.feedback.set({ kind: 'success', text: `${product.name} removed from the inventory.` });
    });
  }

  isLowStock(product: Product): boolean {
    return product.quantity <= product.reorderLevel;
  }

  expiryState(product: Product): ExpiryState {
    if (!product.expiryDate) {
      return 'none';
    }

    if (product.expiryDate < this.today) {
      return 'expired';
    }

    return product.expiryDate <= this.soonCutoff ? 'soon' : 'ok';
  }

  private load(): void {
    this.run(this.loading, this.api.getAll(this.search(), this.filter()), (products) =>
      this.products.set(products),
    );
  }

  /** Runs one API call: flips a busy flag, unsubscribes on destroy, reports failures. */
  private run<T>(
    busy: WritableSignal<boolean>,
    source: Observable<T>,
    onSuccess: (value: T) => void,
  ): void {
    busy.set(true);

    source
      .pipe(
        takeUntilDestroyed(this.destroyRef),
        finalize(() => busy.set(false)),
      )
      .subscribe({
        next: onSuccess,
        error: (error: Error) => this.feedback.set({ kind: 'error', text: error.message }),
      });
  }
}
