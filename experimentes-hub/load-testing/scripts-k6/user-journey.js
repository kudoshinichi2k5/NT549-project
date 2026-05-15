import exec from 'k6/execution';
import http from 'k6/http';
import { check, sleep } from 'k6';

const target = JSON.parse(open('../configs/target.json'));

function stringEnv(name, fallback = '') {
  const value = __ENV[name];
  return value === undefined || value === null || value === '' ? fallback : String(value).trim();
}

function numberEnv(name, fallback) {
  const value = Number(__ENV[name]);
  return Number.isFinite(value) ? value : fallback;
}

function stripTrailingSlash(value) {
  return String(value || '').replace(/\/+$/, '');
}

function normalizePath(value, fallback) {
  const selected = String(value || fallback || '').trim();
  return selected.startsWith('/') ? selected : `/${selected}`;
}

function csvEnv(name) {
  const value = stringEnv(name);
  if (!value) {
    return [];
  }

  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function randomInt(min, max) {
  if (max <= min) {
    return min;
  }

  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomChoice(items) {
  if (!Array.isArray(items) || items.length === 0) {
    return null;
  }

  return items[randomInt(0, items.length - 1)];
}

const CONFIG = {
  baseUrl: stripTrailingSlash(stringEnv('BASE_URL', target.base_url || 'http://mini-ecommerce.tienphatng237.com')),
  loginEndpoint: normalizePath(stringEnv('LOGIN_ENDPOINT', target.login_endpoint || '/api/v1/users/login'), '/api/v1/users/login'),
  productsEndpoint: normalizePath(stringEnv('PRODUCTS_ENDPOINT', target.products_endpoint || '/api/v1/products'), '/api/v1/products'),
  ordersEndpoint: normalizePath(stringEnv('ORDERS_ENDPOINT', target.orders_endpoint || '/api/v1/orders'), '/api/v1/orders'),
  customerEmail: stringEnv('CUSTOMER_EMAIL'),
  customerPassword: stringEnv('CUSTOMER_PASSWORD'),
  customerEmails: csvEnv('CUSTOMER_EMAILS'),
  customerCount: Math.max(1, Math.trunc(numberEnv('CUSTOMER_COUNT', 1))),
  customerEmailPrefix: stringEnv('K6_CUSTOMER_EMAIL_PREFIX_OVERRIDE', stringEnv('CUSTOMER_EMAIL_PREFIX')),
  customerEmailDomain: stringEnv('CUSTOMER_EMAIL_DOMAIN', 'example.test'),
  authToken: stringEnv('AUTH_TOKEN'),
  catalogPageSize: Math.max(1, Math.trunc(numberEnv('CATALOG_PAGE_SIZE', 12))),
  thinkTimeMin: Math.max(0, numberEnv('THINK_TIME_MIN', 0.5)),
  thinkTimeMax: Math.max(0, numberEnv('THINK_TIME_MAX', 2.0)),
  requestTimeout: stringEnv('REQUEST_TIMEOUT', '30s'),
};

if (CONFIG.thinkTimeMax < CONFIG.thinkTimeMin) {
  CONFIG.thinkTimeMax = CONFIG.thinkTimeMin;
}

function buildStages() {
  const start = Math.max(0, Math.trunc(numberEnv('VU_START', 10)));
  const max = Math.max(start, Math.trunc(numberEnv('VU_MAX', 300)));
  const step = Math.max(1, Math.trunc(numberEnv('VU_STEP', 30)));
  const duration = stringEnv('VU_TIME_UNIT', '20s');
  const rampDown = stringEnv('VU_RAMP_DOWN_DURATION', '30s');
  const stages = [];

  let target = start;
  while (target < max) {
    target = Math.min(max, target + step);
    stages.push({ duration, target });
  }

  if (stages.length === 0) {
    stages.push({ duration, target: max });
  }

  stages.push({ duration: rampDown, target: 0 });
  return stages;
}

export const options = {
  scenarios: {
    user_journey: {
      executor: 'ramping-vus',
      exec: 'userJourneyScenario',
      startVUs: Math.max(0, Math.trunc(numberEnv('VU_START', 10))),
      stages: buildStages(),
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    'http_req_duration{service:api-gateway}': ['p(95)<1000'],
    'http_req_failed{service:api-gateway}': ['rate<0.05'],
  },
};

function requestParams(step, token = '') {
  return {
    timeout: CONFIG.requestTimeout,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      'Content-Type': 'application/json',
    },
    tags: {
      app: 'mini-ecommerce',
      namespace: 'mini-ecommerce',
      service: 'api-gateway',
      target: 'api-gateway',
      script: 'user-journey',
      step,
    },
  };
}

function url(path, query = '') {
  return `${CONFIG.baseUrl}${path}${query}`;
}

function safeJson(response) {
  try {
    return response.json();
  } catch (_error) {
    return null;
  }
}

function think() {
  const seconds = CONFIG.thinkTimeMin === CONFIG.thinkTimeMax
    ? CONFIG.thinkTimeMin
    : Math.random() * (CONFIG.thinkTimeMax - CONFIG.thinkTimeMin) + CONFIG.thinkTimeMin;
  sleep(seconds);
}

function login(email) {
  if (!CONFIG.customerPassword) {
    throw new Error('Can CUSTOMER_PASSWORD de login customer.');
  }

  const response = http.post(
    url(CONFIG.loginEndpoint),
    JSON.stringify({
      email,
      password: CONFIG.customerPassword,
    }),
    requestParams('login')
  );

  check(response, {
    'login returns 200': (res) => res.status === 200,
  });

  const payload = safeJson(response);
  const token = payload?.access_token || '';
  if (!token) {
    throw new Error(`Login failed. status=${response.status}`);
  }

  return token;
}

function buildCustomerEmails() {
  if (CONFIG.customerEmails.length > 0) {
    return CONFIG.customerEmails;
  }

  if (CONFIG.customerCount === 1) {
    if (!CONFIG.customerEmail) {
      throw new Error('Can CUSTOMER_EMAIL khi CUSTOMER_COUNT=1.');
    }

    return [CONFIG.customerEmail];
  }

  if (!CONFIG.customerEmailPrefix) {
    throw new Error('Can CUSTOMER_EMAIL_PREFIX khi muon chay nhieu customer.');
  }

  return Array.from({ length: CONFIG.customerCount }, (_unused, index) => (
    `${CONFIG.customerEmailPrefix}.${index + 1}@${CONFIG.customerEmailDomain}`
  ));
}

export function setup() {
  if (CONFIG.authToken && CONFIG.customerCount === 1 && CONFIG.customerEmails.length === 0 && !CONFIG.customerEmailPrefix) {
    return {
      tokens: [CONFIG.authToken],
    };
  }

  const emails = buildCustomerEmails();
  const tokens = emails.map((email) => login(email));

  return {
    tokens,
  };
}

function listProducts() {
  const response = http.get(
    url(CONFIG.productsEndpoint, `?page=0&size=${CONFIG.catalogPageSize}`),
    requestParams('products_list')
  );

  check(response, {
    'product list returns 200': (res) => res.status === 200,
  });

  const payload = safeJson(response);
  const items = Array.isArray(payload?.items) ? payload.items : [];

  return {
    response,
    items: items.filter((item) => item?.id),
  };
}

function getProduct(productId) {
  const response = http.get(
    url(`${CONFIG.productsEndpoint}/${productId}`),
    requestParams('product_detail')
  );

  check(response, {
    'product detail returns 200': (res) => res.status === 200,
  });

  return safeJson(response);
}

function listOrders(token) {
  const response = http.get(
    url(CONFIG.ordersEndpoint),
    requestParams('orders_list', token)
  );

  check(response, {
    'orders list returns 200': (res) => res.status === 200,
  });

  return safeJson(response);
}

export function userJourneyScenario(data) {
  const tokens = Array.isArray(data?.tokens) ? data.tokens.filter(Boolean) : [];
  if (tokens.length === 0) {
    throw new Error('Khong lay duoc token tu setup().');
  }

  const vuIndex = Math.max(0, (exec.vu.idInTest || 1) - 1);
  const token = tokens[vuIndex % tokens.length];

  think();

  const catalog = listProducts();
  const product = randomChoice(catalog.items);
  if (!product?.id) {
    return;
  }

  think();
  getProduct(product.id);

  think();
  listOrders(token);
}

export default function (data) {
  return userJourneyScenario(data);
}
