import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { catchError, throwError } from 'rxjs';
import { environment } from '@env/environment';

/** The error shape ASP.NET Core returns (RFC 7807 problem details). */
interface ApiProblemDetails {
  title?: string;
  detail?: string;
  errors?: Record<string, string[]>;
}

const isApiRequest = (url: string): boolean =>
  url === environment.apiUrl || url.startsWith(`${environment.apiUrl}/`);

const getValidationMessage = (problem: ApiProblemDetails): string =>
  problem.errors ? Object.values(problem.errors).flat().join(' ') : '';

const getMessage = (error: HttpErrorResponse): string => {
  if (error.status === 0) {
    return 'Cannot reach the API. Check that the backend is running.';
  }

  const problem = (error.error ?? {}) as ApiProblemDetails;

  return (
    getValidationMessage(problem) ||
    problem.title ||
    problem.detail ||
    'The request failed. Please try again.'
  );
};

/**
 * Turns every failed API call into a plain Error with a message worth showing the user,
 * so no component has to dig through the HTTP response itself.
 */
export const apiErrorInterceptor: HttpInterceptorFn = (request, next) =>
  next(request).pipe(
    catchError((error: unknown) => {
      if (!(error instanceof HttpErrorResponse) || !isApiRequest(request.url)) {
        return throwError(() => error);
      }

      return throwError(() => new Error(getMessage(error)));
    }),
  );
