import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'products' },
  {
    path: 'products',
    loadComponent: () => import('@features/products/products-page').then((m) => m.ProductsPage),
  },
  { path: '**', redirectTo: 'products' },
];
