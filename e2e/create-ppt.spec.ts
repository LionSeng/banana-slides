/**
 * PPT创建流程E2E测试
 */

import { test, expect } from '@playwright/test'

test.describe('从想法创建PPT', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
  })

  test('完整的PPT创建流程', async ({ page }) => {
    // 1. 点击"从想法创建"
    await page.click('text=/从想法创建/i')
    
    // 2. 输入想法/主题
    const ideaInput = page.locator('textarea, input[type="text"]').first()
    await ideaInput.fill('生成一份关于人工智能的简短PPT，共3页')
    
    // 3. 点击生成（根据实际UI调整）
    await page.click('button:has-text("生成"), button:has-text("创建"), button:has-text("开始")')
    
    // 4. 等待大纲生成（可能需要较长时间）
    await page.waitForSelector('.outline-card, [data-testid="outline-item"]', {
      timeout: 60000
    })
    
    // 5. 验证大纲已生成
    const outlineItems = page.locator('.outline-card, [data-testid="outline-item"]')
    await expect(outlineItems).toHaveCount(3, { timeout: 10000 })
  })

  test('应该能上传模板图片', async ({ page }) => {
    // 导航到创建页面
    await page.click('text=/从想法创建/i')
    
    // 查找文件上传区域
    const fileInput = page.locator('input[type="file"]')
    
    if (await fileInput.count() > 0) {
      // 上传测试图片
      await fileInput.setInputFiles('./e2e/fixtures/test-template.png')
      
      // 验证上传成功（根据实际UI调整）
      await expect(page.locator('text=/上传成功|模板已上传/i')).toBeVisible({ timeout: 10000 })
    }
  })
})

test.describe('API集成测试', () => {
  test('应该能创建项目', async ({ request }) => {
    const response = await request.post('http://localhost:5000/api/projects', {
      data: {
        creation_type: 'idea',
        idea_prompt: 'E2E测试项目'
      }
    })
    
    expect(response.ok()).toBeTruthy()
    
    const data = await response.json()
    expect(data.success).toBe(true)
    expect(data.data.project_id).toBeTruthy()
    
    // 清理：删除测试项目
    const projectId = data.data.project_id
    await request.delete(`http://localhost:5000/api/projects/${projectId}`)
  })

  test('应该能获取项目详情', async ({ request }) => {
    // 先创建项目
    const createResponse = await request.post('http://localhost:5000/api/projects', {
      data: {
        creation_type: 'idea',
        idea_prompt: 'E2E测试项目'
      }
    })
    
    const createData = await createResponse.json()
    const projectId = createData.data.project_id
    
    // 获取详情
    const getResponse = await request.get(`http://localhost:5000/api/projects/${projectId}`)
    
    expect(getResponse.ok()).toBeTruthy()
    
    const getData = await getResponse.json()
    expect(getData.success).toBe(true)
    expect(getData.data.project_id).toBe(projectId)
    
    // 清理
    await request.delete(`http://localhost:5000/api/projects/${projectId}`)
  })
})

