/** Matches StockFilter on the API. */
export type StockFilter = 'All' | 'LowStock' | 'Expiring';

/** The fields the user can fill in, i.e. what gets POSTed or PUT. */
export interface ProductInput {
  name: string;
  barcode: string;
  category: string | null;
  quantity: number;
  reorderLevel: number;
  wholesalePrice: number;
  retailPrice: number;
  /** ISO date string, e.g. "2027-08-31", or null when the item does not expire. */
  expiryDate: string | null;
}

/** What the API sends back: the input plus the fields the server owns. */
export interface Product extends ProductInput {
  id: number;
  createdAt: string;
}
