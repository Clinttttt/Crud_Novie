import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '@env/environment';
import { Product, ProductInput, StockFilter } from './product.model';

/**
 * The only place in the client that knows the HTTP API exists. Components ask this
 * service for data and never build URLs themselves.
 */
@Injectable({ providedIn: 'root' })
export class ProductService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/products`;

  getAll(search: string, filter: StockFilter): Observable<Product[]> {
    let params = new HttpParams().set('filter', filter);

    if (search.trim()) {
      params = params.set('search', search.trim());
    }

    return this.http.get<Product[]>(this.url, { params });
  }

  create(product: ProductInput): Observable<Product> {
    return this.http.post<Product>(this.url, product);
  }

  update(id: number, product: ProductInput): Observable<void> {
    return this.http.put<void>(`${this.url}/${id}`, product);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${this.url}/${id}`);
  }
}
