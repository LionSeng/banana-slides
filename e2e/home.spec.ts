/**
 * 首页E2E测试
 */

import { test, expect } from '@playwright/test'

test.describe('首页', () => {
  test('应该正确加载首页', async ({ page }) => {
    await page.goto('/')
    
    // 检查页面标题或主要元素
    await expect(page).toHaveTitle(/蕉幻|Banana/i)
  })

  test('应该显示创建项目的选项', async ({ page }) => {
    await page.goto('/')
    
    // 检查是否有创建选项（根据实际UI调整选择器）
    const createOptions = page.locator('text=/从想法创建|从大纲创建|从描述创建/i')
    await expect(createOptions.first()).toBeVisible()
  })

  test('应该能够导航到创建页面', async ({ page }) => {
    await page.goto('/')
    
    // 点击创建按钮
    await page.click('text=/开始创建|创建项目|从想法创建/i')
    
    // 验证导航（根据实际路由调整）
    await expect(page).toHaveURL(/\/create|\/new|\/outline/i)
  })
})

test.describe('API健康检查', () => {
  test('后端API应该正常响应', async ({ request }) => {
    const response = await request.get('http://localhost:5000/health')
    
    expect(response.ok()).toBeTruthy()
    
    const data = await response.json()
    expect(data.status).toBe('ok')
  })
})

