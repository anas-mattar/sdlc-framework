# Frontend: Forms Architecture (MANDATORY)

Stack:

| Layer | Library | Purpose |
|-------|---------|---------|
| Validation | Zod (schemas per domain, see Rule F8b) | Runtime validation + type inference |
| State | React Hook Form (`useForm`) | Form state, submission, field control |
| UI | shadcn/ui Form (`components/ui/form.tsx`) | `Form`, `FormField`, `FormItem`, `FormLabel`, `FormControl`, `FormMessage` |
| Notifications | Sonner (`toast`) | Success/error notifications |
| API | tRPC mutations | Server communication |

## Rule F8a -- Form component structure (MANDATORY)

Every form in `components/forms/` MUST follow this exact structure:

```tsx
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { trpc } from '@/lib/trpc/client';
import { myFeatureSchema, type MyFeature } from '@/lib/my-feature/schemas';
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';

type FormData = z.infer<typeof myFeatureSchema>;

interface MyFeatureFormProps {
  data?: MyFeature;                // undefined = create
  onCancel?: () => void;
  onSubmitParent?: () => void;     // parent refresh callback
  cancelText?: string;
}

export function MyFeatureForm({
  data, onCancel, onSubmitParent, cancelText = 'Cancel',
}: MyFeatureFormProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(myFeatureSchema),
    defaultValues: {
      code: data?.code ?? '',
      name: data?.name ?? '',
    },
  });

  const addMutation = trpc.myFeature.add.useMutation();
  const updateMutation = trpc.myFeature.update.useMutation();

  const onSubmit = async (formData: FormData) => {
    try {
      if (data?.id) {
        await updateMutation.mutateAsync({ id: data.id, ...formData });
        toast.success('Updated successfully');
      } else {
        await addMutation.mutateAsync(formData);
        toast.success('Created successfully');
      }
      onSubmitParent?.();
    } catch {
      toast.error('Something went wrong');
    }
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="code"
          render={({ field }) => (
            <FormItem>
              <FormLabel>
                Code <span className="pl-1 font-bold text-red-500">*</span>
              </FormLabel>
              <FormControl><Input placeholder="Enter code" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl><Input placeholder="Enter name" {...field} /></FormControl>
              <FormDescription>Optional description</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="flex justify-end space-x-2">
          {onCancel && (
            <Button variant="ghost" type="button" onClick={onCancel}>{cancelText}</Button>
          )}
          <Button disabled={form.formState.isSubmitting} type="submit">
            {data ? 'Update' : 'Add'}
          </Button>
        </div>
      </form>
    </Form>
  );
}
```

## Rule F8a-1 -- Mutation wiring (allowed variants)

Two wirings are allowed; field state and validation MUST be RHF + zodResolver in
either case:

1. **Form-owned mutation** (default, as in F8a): the form calls
   `trpc.<router>.<procedure>.useMutation()` directly and notifies the parent via
   `onSubmitParent`.
2. **Page-owned mutation**: the page owning the screen passes an async
   `onSubmit(input)` prop; the page calls the tRPC mutation and owns cache
   invalidation (`trpc.useUtils()`). Use this when one page orchestrates several
   modals/forms over the same query cache (e.g. a chart-of-accounts style screen).

In both variants the form itself shows Sonner toasts and disables submit via
`form.formState.isSubmitting`.

## Rule F8b -- Zod schemas

Live in `src/schema/<domain>.ts` (see `docs/stacks/<frontend>/rules.md`). Never define Zod schemas inline in form files.

```ts
import { z } from 'zod';

export const myFeatureInputSchema = z.object({
  code: z.string().min(1, 'Code required').max(50),
  name: z.string().min(1, 'Name required').max(200),
  status: z.enum(['Open', 'Active', 'Completed']),
  amount: z.number().min(0.01, 'Must be positive'),
  notes: z.string().optional().nullable(),
  date: z.date(),
});

export const myFeatureCreateSchema = myFeatureInputSchema
  .extend({ extraField: z.string().optional() })
  .refine(
    (d) => d.status !== 'Active' || !!d.extraField,
    { message: 'Extra field required when Active', path: ['extraField'] }
  );

export const myFeatureUpdateSchema = myFeatureInputSchema.extend({ id: z.string() });
export type MyFeatureInput = z.infer<typeof myFeatureInputSchema>;
```

## Rule F8c -- Field input components

| Field type | Component | Source |
|------------|-----------|--------|
| Text/string | `<Input {...field} />` | `@/components/ui/input` |
| Date | `<DatePicker {...field} />` | custom date picker |
| Domain dropdown | `<EntityDropdown value={field.value} onChange={field.onChange} />` | `@/components/dropdowns/*` |
| Enum select | `<Select>` | `@/components/ui/select` |
| Textarea | `<Textarea {...field} />` | `@/components/ui/textarea` |
| Number | `<Input type="number" {...field} />` | `@/components/ui/input` |

## Rule F8d -- File organization

All data-entry forms live in `components/forms/`. Name as `{feature}-form.tsx` or `{feature}-{action}-form.tsx`.

## Form rules

- Every form MUST use `zodResolver` -- no manual validation, no `useState` field state.
- Every form MUST be dual-mode (create/update) via the `data` prop when the entity
  supports both operations. Single-action forms (e.g. export, remove-with-reason)
  omit the unused mode but keep the same structure.
- Required fields MUST show `<span className="pl-1 font-bold text-red-500">*</span>` in `FormLabel`.
- `<FormMessage />` auto-displays Zod errors -- no manual wiring.
- Submit button MUST be disabled during submission via `form.formState.isSubmitting`.
- Toast notifications MUST use `sonner` (`toast.success()` / `toast.error()`).
- Cross-field dependencies use `form.watch()` and `form.setValue()`.
- Never use blocking sync calls in form handlers.
