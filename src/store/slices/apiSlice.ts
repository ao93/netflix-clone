import { API_ENDPOINT_URL, TMDB_V3_API_KEY } from "src/constant";
import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";

export const tmdbApi = createApi({
  reducerPath: "tmdbApi",
  baseQuery: fetchBaseQuery({
    baseUrl: API_ENDPOINT_URL,
    prepareHeaders: (headers) => {
      headers.set("Authorization", `Bearer ${TMDB_V3_API_KEY}`);
      return headers;
    },
  }),
  endpoints: (build) => ({}),
});