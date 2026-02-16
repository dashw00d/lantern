import type { ReactNode } from 'react';
import { cn } from '../../lib/utils';

interface FormFieldProps {
  label: string;
  htmlFor: string;
  children: ReactNode;
  className?: string;
}

export function FormField({ label, htmlFor, children, className }: FormFieldProps) {
  return (
    <label htmlFor={htmlFor} className={cn('space-y-1 text-sm', className)}>
      <span>{label}</span>
      {children}
    </label>
  );
}
