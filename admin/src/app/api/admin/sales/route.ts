import { NextRequest } from "next/server";
import { proxyAdminApi } from "../admin-api";
export const dynamic = "force-dynamic";
export async function GET(request: NextRequest) { return proxyAdminApi(request, "/v1/admin/sales"); }
