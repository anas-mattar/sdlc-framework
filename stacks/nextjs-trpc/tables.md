# Frontend: Tables Architecture (MANDATORY)

The frontend uses a **two-layer base table system**. All new tables MUST compose from these base components -- do not duplicate pagination, search, sort, or URL-state logic.

Composition levels:

- **Server-paged lists** (the normal case) compose `QueryDataTable` (Layer 2):
  URL-driven page/limit/search/sortBy/sortDir.
- **Matrix-style grids** (dynamic columns, full dataset rendered, no server
  paging) may compose `BaseDataTable` (Layer 1) directly with a `ColumnDef`
  factory. They still get `columns.tsx` and the feature folder; they skip URL
  state because there is nothing to page.
  > Examples: a permission matrix, a fixed checklist.

Matrix-grid support on `BaseDataTable`:

- Per-column styling via tanstack `ColumnDef.meta`: `headerClassName` /
  `cellClassName` are merged onto the `<th>`/`<td>` (e.g. a highlighted column,
  sticky first columns, centered checkbox cells).
- Labelled section bands via the optional `rowGroupHeader` prop
  (`{ getGroupKey, render, rowClassName?, cellClassName? }`): a full-width band
  row is rendered whenever `getGroupKey` changes between consecutive rows.

## Layered structure

```
Layer 0: components/ui/table.tsx          Pure HTML primitives
Layer 1: base/base-data-table.tsx         BaseDataTable<TData, TFilter>
         @tanstack/react-table, rendering, debounced search,
         pagination UI, sorting UI, filter slots, loading/empty
Layer 2: base/query-data-table.tsx        QueryDataTable<TData, TFilter>
         Wraps BaseDataTable + URL state (page/limit/search/sortBy/sortDir
         as query params), tRPC query execution, page-bounds correction
Layer 3: Feature tables                   e.g. OrderTable, SupplierTable, ...
         Concrete tRPC hook wrapper, domain filter state, column defs,
         configuration (enableSorting, searchPlaceholder, etc.)
```

## Base types

```ts
// base/base-data-table.tsx
export interface PaginatedResponse<T> {
  items: T[];
  totalPages: number;
  totalCount?: number;
  currentPage?: number;
}

export interface BaseTableFilter {
  searchTerm?: string;
  // plus the project's global scope fields, defined once here
  // > Example: organisationCode?, siteCode? — whatever scopes every query
}

export interface BaseTableConfig {
  enableSorting?: boolean;
  enableFiltering?: boolean;
  enablePagination?: boolean;
  searchPlaceholder?: string;
  searchKey?: string;
  pageSizeOptions?: number[];
  defaultPageSize?: number;
  tableHeight?: string;
  searchFromUrl?: boolean;
}

// base/query-data-table.tsx
export interface QueryParams<TFilter extends BaseTableFilter> {
  page: number;
  size: number;
  sortBy?: string;
  sortDir?: 'asc' | 'desc';
  filter: TFilter;
}

export interface QueryResult {
  data: any;
  isLoading: boolean;
  isFetching: boolean;
  refetch: (options?: any) => Promise<any>;
}
```

## Rule F11a -- Creating a new table

Compose `QueryDataTable`. Never rewrite table boilerplate.

```tsx
'use client';
import React, { useState, useCallback } from 'react';
import { type ColumnDef } from '@tanstack/react-table';
import { trpc } from '@/lib/trpc/client';
import { QueryDataTable, type BaseTableFilter } from '@/components/tables/base';

interface MyFeatureTableFilter extends BaseTableFilter {
  status?: string;
  categoryId?: string;
}

interface MyFeatureTableProps<TData> {
  columns: ColumnDef<TData, unknown>[];
  actions?: React.ReactNode;
}

export function MyFeatureTable<TData>({ columns, actions }: MyFeatureTableProps<TData>) {
  const [status, setStatus] = useState<string | undefined>(undefined);

  const useMyFeatureQuery = (params: {
    page: number; size: number; sortBy?: string; sortDir?: 'asc' | 'desc';
    filter: MyFeatureTableFilter;
  }) => {
    const result = trpc.myFeature.list.useQuery({
      page: params.page,
      size: params.size,
      sortBy: params.sortBy,
      sortDir: params.sortDir,
      filter: { ...params.filter, status: status === 'SelectValue:All' ? undefined : status },
    });
    return {
      data: result.data ?? undefined,
      isLoading: result.isLoading,
      isFetching: result.isFetching,
      refetch: result.refetch,
    };
  };

  const handleClearFilters = useCallback(() => setStatus(undefined), []);

  const filterComponents = [
    <StatusDropdown key="status" value={status ?? 'SelectValue:All'} onChange={setStatus} showSelectAll />,
  ];

  return (
    <QueryDataTable
      columns={columns}
      useQuery={useMyFeatureQuery}
      filterComponents={filterComponents}
      onClearFilters={handleClearFilters}
      actions={actions}
      config={{
        enableSorting: true,
        enableFiltering: true,
        searchPlaceholder: 'Search my features...',
        pageSizeOptions: [10, 20, 30, 40, 50],
      }}
      emptyMessage="No results found."
    />
  );
}
```

## Rule F11b -- Column definitions

Columns live in a separate `columns.tsx` using `ColumnDef<T>` from `@tanstack/react-table`.

```tsx
'use client';
import { type ColumnDef } from '@tanstack/react-table';
import { type MyFeature } from '@/lib/my-feature/schemas';
import { CellAction } from './cell-action';
import { CopyToClipboard } from '@/components/copy-to-clipboard';
import Link from 'next/link';
import { formatDate } from '@/lib/utils';

export const columns: ColumnDef<MyFeature>[] = [
  {
    accessorKey: 'code',
    header: 'Code',
    cell: ({ row: { original } }) => (
      <div className="flex items-center space-x-2">
        <Link href={`/my-feature/details/${original.code}`} className="font-semibold hover:underline">
          {original.code}
        </Link>
        <CopyToClipboard text={original.code} />
      </div>
    ),
  },
  { accessorKey: 'name', header: 'Name' },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: (cell) => <StatusBadge status={cell.row.original.status} />,
  },
  {
    accessorKey: 'createdDate',
    header: 'Created Date',
    cell: ({ row }) => <div>{row.original.createdDate ? formatDate(row.original.createdDate) : '-'}</div>,
  },
  { id: 'actions', cell: ({ row }) => <CellAction data={row.original} /> }, // ALWAYS last
];
```

Column variants via slicing:

```tsx
export const columnsWithExtra = [
  ...columns.slice(0, 3),
  { accessorKey: 'extraField', header: 'Extra' },
  ...columns.slice(3),
];

export const GetColumns = (status: StatusType) => {
  const head = columns.slice(0, columns.length - 1);
  const last = columns.slice(columns.length - 1);
  switch (status) {
    case 'Active':
      head.push({ id: 'activeDate', header: 'Active Since',
        cell: ({ row }) => formatDate(row.original.activeDate) });
      break;
  }
  head.push(...last);
  return head;
};
```

Column rules:
- Every feature folder MUST have a `columns.tsx`.
- Use `accessorKey` for simple data; `cell` for custom JSX (badges, links, formatted values).
- `id: 'actions'` MUST be last. Optional `id: 'select'` checkbox column goes first.
- Export variant columns as separate constants/factories. Never define columns inline.

## Rule F11c -- File organization

```
components/tables/{feature}-tables/
├── table.tsx           # composes QueryDataTable
├── columns.tsx         # ColumnDef<T>[]
└── cell-action.tsx     # row action dropdown
```

Sub-tables (e.g., order lines):

```
components/tables/{feature}-tables/
├── table.tsx
├── columns.tsx
├── cell-action.tsx
└── {sub-feature}/
    ├── table.tsx
    ├── columns.tsx
    └── cell-action.tsx
```
